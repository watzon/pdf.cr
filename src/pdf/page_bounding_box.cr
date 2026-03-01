module PDF
  class Page
    # Creates a bounding box that constrains content flow within a
    # rectangular area. The block receives the bounding box, which
    # provides local coordinate system and cursor management.
    #
    # ```
    # page.bounding_box(at: {50, 700}, width: 400, height: 300) do |box|
    #   box.text("Content constrained to this area")
    # end
    # ```
    #
    # The bounding box translates coordinates so that (0, 0) is the
    # top-left corner of the box. The cursor starts at the top and
    # moves down as content is added.
    def bounding_box(
      *,
      at : Tuple(Number, Number),
      width : Number,
      height : Number? = nil,
      &block : BoundingBoxContext ->
    ) : Layout::BoundingBox
      box = Layout::BoundingBox.new(
        x: at[0].to_f,
        y: at[1].to_f,
        box_width: width.to_f,
        fixed_height: height.try(&.to_f),
      )
      ctx = BoundingBoxContext.new(self, box)
      block.call(ctx)
      box
    end

    # Creates a multi-column layout box. Content flows from one column
    # to the next before moving to a new page.
    #
    # ```
    # page.column_box(at: {50, 700}, width: 500, height: 600, columns: 2) do |col|
    #   col.text("This text will flow across columns")
    # end
    # ```
    def column_box(
      *,
      at : Tuple(Number, Number),
      width : Number,
      height : Number? = nil,
      columns : Int32 = 2,
      spacer : Number = 12,
      &block : ColumnBoxContext ->
    ) : Layout::ColumnBox
      box = Layout::ColumnBox.new(
        x: at[0].to_f,
        y: at[1].to_f,
        width: width.to_f,
        height: height.try(&.to_f),
        columns: columns,
        spacer: spacer.to_f,
      )
      ctx = ColumnBoxContext.new(self, box)
      block.call(ctx)
      box
    end

    # Context object passed to bounding_box blocks. Provides
    # drawing methods that are constrained to the bounding box.
    class BoundingBoxContext
      getter page : Page
      getter box : Layout::BoundingBox

      def initialize(@page : Page, @box : Layout::BoundingBox)
      end

      # Returns the current cursor position (relative to box top).
      def cursor : Float64
        @box.cursor
      end

      # Moves the cursor down by the given amount.
      def move_down(amount : Number) : Nil
        @box.move_down(amount.to_f)
      end

      # Draws text at the current cursor position within the box.
      def text(content : String, *, font_name : String = "Helvetica", font_size : Number = 12, align : Symbol = :left) : Nil
        abs_pos = @box.to_absolute({0.0, @box.height - @box.cursor})
        @page.font(font_name, size: font_size)
        @page.text(content, at: {abs_pos[0], abs_pos[1]})
        # Move cursor down by line height
        @box.move_down(font_size.to_f * 1.2)
      end

      # Draws formatted text within the bounding box at the current cursor.
      def formatted_text(
        fragments : Array(Text::Formatted::FragmentHash),
        *,
        align : Symbol = :left,
        leading : Number = 0,
        font_name : String = "Helvetica",
        font_size : Number = 12
      ) : Array(Text::Formatted::FragmentHash)
        abs_pos = @box.to_absolute({0.0, @box.height - @box.cursor})
        remaining_height = @box.cursor

        box = Text::Formatted::Box.new(
          formatted_text: fragments,
          at: {abs_pos[0], abs_pos[1]},
          width: @box.width,
          height: remaining_height,
          align: align,
          leading: leading.to_f,
          document: @page.document,
          font_name: font_name,
          font_size: font_size.to_f,
        )
        remaining = box.render(@page)
        @box.move_down(box.rendered_height)
        remaining
      end

      # Draws the outline of the bounding box (useful for debugging).
      def stroke_bounds : Nil
        tl = @box.absolute_top_left
        tr = @box.absolute_top_right
        br = @box.absolute_bottom_right
        bl = @box.absolute_bottom_left

        @page.move_to(tl[0], tl[1])
        @page.line_to(tr[0], tr[1])
        @page.line_to(br[0], br[1])
        @page.line_to(bl[0], bl[1])
        @page.line_to(tl[0], tl[1])
        @page.stroke
      end

      # Returns the available width within the box.
      def width : Float64
        @box.width
      end

      # Returns the available height within the box.
      def height : Float64
        @box.height
      end
    end

    # Context object for column_box blocks. Extends BoundingBoxContext
    # with column-specific functionality.
    class ColumnBoxContext
      getter page : Page
      getter box : Layout::ColumnBox

      def initialize(@page : Page, @box : Layout::ColumnBox)
      end

      # Returns the current cursor position.
      def cursor : Float64
        @box.cursor
      end

      # Moves the cursor down.
      def move_down(amount : Number) : Nil
        @box.move_down(amount.to_f)
      end

      # Draws text at the current cursor position within the current column.
      def text(content : String, *, font_name : String = "Helvetica", font_size : Number = 12, align : Symbol = :left) : Nil
        abs_pos = @box.to_absolute({0.0, @box.height - @box.cursor})
        @page.font(font_name, size: font_size)
        @page.text(content, at: {abs_pos[0], abs_pos[1]})
        @box.move_down(font_size.to_f * 1.2)
      end

      # Draws formatted text within the current column. If text overflows,
      # it advances to the next column automatically.
      def formatted_text(
        fragments : Array(Text::Formatted::FragmentHash),
        *,
        align : Symbol = :left,
        leading : Number = 0,
        font_name : String = "Helvetica",
        font_size : Number = 12
      ) : Array(Text::Formatted::FragmentHash)
        remaining = fragments

        loop do
          abs_pos = @box.to_absolute({0.0, @box.height - @box.cursor})
          remaining_height = @box.cursor

          break if remaining_height <= 0 || remaining.empty?

          text_box = Text::Formatted::Box.new(
            formatted_text: remaining,
            at: {abs_pos[0], abs_pos[1]},
            width: @box.width,
            height: remaining_height,
            align: align,
            leading: leading.to_f,
            document: @page.document,
            font_name: font_name,
            font_size: font_size.to_f,
          )
          remaining = text_box.render(@page)
          @box.move_down(text_box.rendered_height)

          break if remaining.empty?

          # Advance to next column
          needs_new_page = @box.advance_column
          break if needs_new_page # caller must handle page breaks
        end

        remaining
      end

      # Returns the column width.
      def width : Float64
        @box.width
      end

      # Returns the box height.
      def height : Float64
        @box.height
      end

      # Returns the current column index.
      def current_column : Int32
        @box.current_column
      end

      # Returns the number of columns.
      def columns : Int32
        @box.columns
      end

      # Draws the outline of the current column.
      def stroke_bounds : Nil
        left = @box.left_side
        right = @box.right_side
        top = @box.absolute_top
        bottom = @box.absolute_bottom

        @page.move_to(left, top)
        @page.line_to(right, top)
        @page.line_to(right, bottom)
        @page.line_to(left, bottom)
        @page.line_to(left, top)
        @page.stroke
      end
    end
  end
end
