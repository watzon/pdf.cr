module PDF
  class Page
    # Overflow modes for plain `text` in a bounding box.
    BOUNDING_BOX_OVERFLOWS = {:truncate, :clip, :visible}

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
    #
    # `overflow` controls plain `text` lines that do not fit:
    # - `:truncate` (default) does not draw the line and returns `false`.
    # - `:clip` draws the line and clips all box content to the box bounds.
    #   It needs a fixed `height`.
    # - `:visible` draws the line outside the box.
    def bounding_box(
      *,
      at : Tuple(Number, Number),
      width : Number,
      height : Number? = nil,
      overflow : Symbol = :truncate,
      &block : BoundingBoxContext ->
    ) : Layout::BoundingBox
      box = Layout::BoundingBox.new(
        x: at[0].to_f,
        y: at[1].to_f,
        box_width: width.to_f,
        fixed_height: height.try(&.to_f),
      )
      LayoutFlow.new(self).run_bounding_box(box, overflow, &block)
      box
    end

    # Creates a multi-column layout box. Content flows from one column
    # to the next. When the last column is full, a new page with the same
    # size starts and the content continues in the first column of a box
    # at the same position. Set `page_break: false` to stop instead: the
    # box is then `full?` and `formatted_text` returns the remaining text.
    #
    # ```
    # page.column_box(at: {50, 700}, width: 500, height: 600, columns: 2) do |col|
    #   col.text("This text will flow across columns")
    # end
    # ```
    #
    # After a page break, `col.page` is the new page. The `page` variable
    # of the enclosing block still refers to the first page.
    def column_box(
      *,
      at : Tuple(Number, Number),
      width : Number,
      height : Number? = nil,
      columns : Int32 = 2,
      spacer : Number = 12,
      page_break : Bool = true,
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
      LayoutFlow.new(self).run_column_box(box, page_break, &block)
      box
    end

    # State shared by a tree of nested box contexts: the page that receives
    # content and the clipping boxes that are open on it. A page break in a
    # nested column box changes the page for all contexts of the tree.
    class LayoutFlow
      getter page : Page

      def initialize(@page : Page)
        @clips = [] of Layout::BoundingBox
      end

      # `relocate` is given to the `BoundingBoxContext` (see there).
      def run_bounding_box(
        box : Layout::BoundingBox,
        overflow : Symbol,
        relocate : (-> Layout::BoundingBox?)? = nil,
        &block : BoundingBoxContext ->
      ) : Nil
        unless BOUNDING_BOX_OVERFLOWS.includes?(overflow)
          raise ArgumentError.new("Unknown overflow: #{overflow}. Use :truncate, :clip or :visible.")
        end
        ctx = BoundingBoxContext.new(self, box, overflow, relocate)
        if overflow == :clip
          raise ArgumentError.new("overflow: :clip needs a fixed height.") if box.stretchy?
          with_clip(box) { block.call(ctx) }
        else
          block.call(ctx)
        end
      end

      def run_column_box(box : Layout::ColumnBox, page_break : Bool, &block : ColumnBoxContext ->) : Nil
        block.call(ColumnBoxContext.new(self, box, page_break))
      end

      # Ends the open clipping regions on the current page, appends a new
      # page with the same size, and opens the same clipping regions on it.
      def start_new_page : Page
        @clips.size.times { @page.restore_graphics_state }
        @page = @page.document.start_new_page(@page.width, @page.height)
        @clips.each { |box| open_clip(box) }
        @page
      end

      private def with_clip(box : Layout::BoundingBox, &) : Nil
        open_clip(box)
        @clips << box
        begin
          yield
        ensure
          @clips.pop
          @page.restore_graphics_state
        end
      end

      private def open_clip(box : Layout::BoundingBox) : Nil
        @page.save_graphics_state
        @page.rectangle(box.absolute_left, box.absolute_bottom, box.width, box.height)
        @page.clip!
      end
    end

    # Methods shared by `BoundingBoxContext` and `ColumnBoxContext`.
    # The including class must define `@flow : LayoutFlow` and a `@box`
    # that is a `Layout::BoundingBox`.
    module BoxContextMethods
      # Tolerance for floating-point height comparisons.
      FIT_EPSILON = 0.0001

      # The page that receives content. It changes after a page break.
      def page : Page
        @flow.page
      end

      # Returns the current cursor position (relative to box bottom).
      def cursor : Float64
        @box.cursor
      end

      # Moves the cursor down by the given amount.
      def move_down(amount : Number) : Nil
        @box.move_down(amount.to_f)
      end

      # Returns the available width within the box.
      def width : Float64
        @box.width
      end

      # Returns the height of the box.
      def height : Float64
        @box.height
      end

      # Narrows the box by `left` and `right` points while the block runs.
      # Text, nested boxes and column widths use the narrower area.
      #
      # ```
      # box.indent(20) do
      #   box.text("Indented")
      # end
      # ```
      def indent(left : Number, right : Number = 0, &) : Nil
        @box.indent(left.to_f, right.to_f) { yield }
      end

      # Creates a bounding box nested in this box. `at` is relative to this
      # box: x from its left edge (after indent and column offset), y from
      # its bottom, as with `cursor`. The default `at` is `{0, cursor}` and
      # the default width is the rest of the width of this box. After the
      # block, the cursor of this box moves below the nested box.
      #
      # ```
      # outer.bounding_box(width: 100, height: 50) do |inner|
      #   inner.text("Nested")
      # end
      # ```
      def bounding_box(
        *,
        at : Tuple(Number, Number)? = nil,
        width : Number? = nil,
        height : Number? = nil,
        overflow : Symbol = :truncate,
        &block : BoundingBoxContext ->
      ) : Layout::BoundingBox
        x, y = nested_origin(at)
        child = Layout::BoundingBox.new(
          x: x,
          y: y,
          box_width: nested_width(at, width),
          fixed_height: height.try(&.to_f),
          parent: @box,
        )
        @flow.run_bounding_box(child, overflow, &block)
        settle_below(child)
        child
      end

      # Creates a column box nested in this box. `at`, `width` and the
      # cursor update work as in `bounding_box`.
      def column_box(
        *,
        at : Tuple(Number, Number)? = nil,
        width : Number? = nil,
        height : Number? = nil,
        columns : Int32 = 2,
        spacer : Number = 12,
        page_break : Bool = true,
        &block : ColumnBoxContext ->
      ) : Layout::ColumnBox
        x, y = nested_origin(at)
        child = Layout::ColumnBox.new(
          x: x,
          y: y,
          width: nested_width(at, width),
          height: height.try(&.to_f),
          parent: @box,
          columns: columns,
          spacer: spacer.to_f,
        )
        @flow.run_column_box(child, page_break, &block)
        settle_below(child)
        child
      end

      # Absolute top-left corner of a nested box.
      private def nested_origin(at : Tuple(Number, Number)?) : Tuple(Float64, Float64)
        if at
          {@box.left_side + at[0].to_f, @box.absolute_bottom + at[1].to_f}
        else
          {@box.left_side, @box.absolute_cursor_y}
        end
      end

      private def nested_width(at : Tuple(Number, Number)?, width : Number?) : Float64
        return width.to_f if width
        @box.width - (at.try(&.[0].to_f) || 0.0)
      end

      # Moves the cursor of this box below a nested box that ends lower.
      private def settle_below(child : Layout::BoundingBox) : Nil
        drop = @box.absolute_cursor_y - child.absolute_bottom
        @box.move_down(drop) if drop > 0
      end

      # Draws one line of plain text with its top at the cursor.
      private def draw_line(content : String, font_name : String, font_size : Float64, x : Float64) : Nil
        page.font(font_name, size: font_size)
        # The first baseline sits one ascender below the top of the line.
        baseline = @box.absolute_cursor_y - font_size * Text::Formatted::FontMeasurer::ASCENDER_RATIO
        page.text(content, at: {x, baseline})
      end

      private def line_fits?(line_height : Float64) : Bool
        line_height <= @box.available_height + FIT_EPSILON
      end
    end

    # Context object passed to bounding_box blocks. Provides
    # drawing methods that are constrained to the bounding box.
    class BoundingBoxContext
      include BoxContextMethods

      getter box : Layout::BoundingBox

      # How plain `text` handles a line that does not fit.
      getter overflow : Symbol

      def initialize(page : Page, box : Layout::BoundingBox, overflow : Symbol = :truncate)
        initialize(LayoutFlow.new(page), box, overflow)
      end

      # `relocate` runs when content does not fit while the box is still
      # empty. It returns a box at a place with more room (for a column box
      # span, the top of the box on a new page), or nil. It runs one time.
      def initialize(
        @flow : LayoutFlow,
        @box : Layout::BoundingBox,
        @overflow : Symbol,
        @relocate : (-> Layout::BoundingBox?)? = nil,
      )
      end

      # Draws a line of text at the current cursor position within the box
      # and moves the cursor down by one line (1.2 x `font_size`).
      #
      # Returns `false` and draws nothing when the box overflow is
      # `:truncate` and the line does not fit above the bottom of the box.
      def text(content : String, *, font_name : String = "Helvetica", font_size : Number = 12, align : Symbol = :left) : Bool
        line_height = font_size.to_f * 1.2
        if @overflow == :truncate && !line_fits?(line_height)
          return false unless relocate && line_fits?(line_height)
        end
        draw_line(content, font_name, font_size.to_f, @box.left_side)
        @box.move_down(line_height)
        true
      end

      # Draws formatted text within the bounding box at the current cursor.
      # Overload that accepts named tuples, e.g. `[{text: "Hi", styles: [:bold]}]`.
      def formatted_text(fragments : Array, **options) : Array(Text::Formatted::FragmentHash)
        formatted_text(Text::Formatted.to_fragment_hashes(fragments), **options)
      end

      def formatted_text(
        fragments : Array(Text::Formatted::FragmentHash),
        *,
        align : Symbol = :left,
        leading : Number = 0,
        font_name : String = "Helvetica",
        font_size : Number = 12,
      ) : Array(Text::Formatted::FragmentHash)
        loop do
          box = Text::Formatted::Box.new(
            formatted_text: fragments,
            at: {@box.left_side, @box.absolute_cursor_y},
            width: @box.width,
            height: @box.available_height,
            align: align,
            leading: leading.to_f,
            document: page.document,
            font_name: font_name,
            font_size: font_size.to_f,
          )
          remaining = box.render(page)
          next if box.nothing_printed? && !remaining.empty? && relocate
          @box.move_down(box.rendered_height)
          return remaining
        end
      end

      # Moves an empty box to the place that `@relocate` gives. Returns
      # `false` when the box has content or no other place is available.
      private def relocate : Bool
        hook = @relocate
        return false unless hook && @box.height <= FIT_EPSILON
        @relocate = nil
        moved = hook.call
        return false unless moved
        @box = moved
        true
      end

      # Draws the outline of the bounding box (useful for debugging).
      def stroke_bounds : Nil
        tl = @box.absolute_top_left
        tr = @box.absolute_top_right
        br = @box.absolute_bottom_right
        bl = @box.absolute_bottom_left

        page.move_to(tl[0], tl[1])
        page.line_to(tr[0], tr[1])
        page.line_to(br[0], br[1])
        page.line_to(bl[0], bl[1])
        page.line_to(tl[0], tl[1])
        page.stroke
      end
    end

    # Context object for column_box blocks. Provides the same methods as
    # `BoundingBoxContext`, plus column flow, spans and page breaks.
    class ColumnBoxContext
      include BoxContextMethods

      getter box : Layout::ColumnBox

      # Whether a new page starts when the last column is full.
      getter? page_break : Bool

      # True when content was placed in the box on the current page. A page
      # break only happens after content was placed: the next page repeats
      # the same geometry, so content that did not fit an empty page will
      # not fit the next one either.
      @placed_on_page = false

      @page_break_hooks = [] of ColumnBoxContext ->

      def initialize(page : Page, box : Layout::ColumnBox, page_break : Bool = true)
        initialize(LayoutFlow.new(page), box, page_break)
      end

      def initialize(@flow : LayoutFlow, @box : Layout::ColumnBox, @page_break : Bool)
      end

      # Registers a block that runs on each new page that this box starts,
      # before content continues. Use it to repeat context such as a header
      # or the box outline.
      #
      # ```
      # col.on_page_break { |c| c.page.text("(continued)", at: {50, 760}) }
      # ```
      def on_page_break(&block : ColumnBoxContext ->) : Nil
        @page_break_hooks << block
      end

      # Draws a line of text at the current cursor position within the
      # current column. It moves to the next column, or to a new page, while
      # the line does not fit. Returns `false` and draws nothing when the box
      # is full.
      def text(content : String, *, font_name : String = "Helvetica", font_size : Number = 12, align : Symbol = :left) : Bool
        line_height = font_size.to_f * 1.2
        until line_fits?(line_height)
          return false unless next_column
        end
        draw_line(content, font_name, font_size.to_f, @box.left_side)
        @box.move_down(line_height)
        @placed_on_page = true
        true
      end

      # Draws formatted text within the current column. If text overflows,
      # it advances to the next column, and then to a new page, automatically.
      # Returns the text that did not fit (only when the box is full).
      # Overload that accepts named tuples, e.g. `[{text: "Hi", styles: [:bold]}]`.
      def formatted_text(fragments : Array, **options) : Array(Text::Formatted::FragmentHash)
        formatted_text(Text::Formatted.to_fragment_hashes(fragments), **options)
      end

      def formatted_text(
        fragments : Array(Text::Formatted::FragmentHash),
        *,
        align : Symbol = :left,
        leading : Number = 0,
        font_name : String = "Helvetica",
        font_size : Number = 12,
      ) : Array(Text::Formatted::FragmentHash)
        remaining = fragments

        until remaining.empty?
          if !@box.full? && @box.available_height > FIT_EPSILON
            text_box = Text::Formatted::Box.new(
              formatted_text: remaining,
              at: {@box.left_side, @box.absolute_cursor_y},
              width: @box.width,
              height: @box.available_height,
              align: align,
              leading: leading.to_f,
              document: page.document,
              font_name: font_name,
              font_size: font_size.to_f,
            )
            remaining = text_box.render(page)
            unless text_box.nothing_printed?
              @box.move_down(text_box.rendered_height)
              @placed_on_page = true
            end
            break if remaining.empty?
          end
          break unless next_column
        end

        remaining
      end

      # Draws content across the full width of the column box (or `width`
      # points of it). The span starts below the lowest content of all
      # columns. After the span, a new section of columns starts below it,
      # beginning with the first column.
      #
      # When the first line of the span does not fit the rest of the box,
      # the span starts at the top of the box on a new page (only with
      # `page_break`, and when content is on the current page). Content that
      # does not fit after that is truncated, as in a stretchy bounding box.
      #
      # `position` is `:left`, `:center` or `:right` when `width` is less
      # than the box width.
      #
      # ```
      # col.span { |s| s.text("Section title") }
      # ```
      def span(width : Number? = nil, *, position : Symbol = :left, &block : BoundingBoxContext ->) : Layout::BoundingBox
        span_width = (width || @box.box_width).to_f
        offset = case position
                 when :left   then 0.0
                 when :center then (@box.box_width - span_width) / 2
                 when :right  then @box.box_width - span_width
                 else
                   raise ArgumentError.new("Unknown span position: #{position}. Use :left, :center or :right.")
                 end
        top = @box.section_bottom
        child = span_box(top, offset, span_width)
        # When the span content does not fit the rest of the box, the span
        # starts at the top of the box on a new page, as other content does.
        relocate = -> : Layout::BoundingBox? {
          if @page_break && @placed_on_page
            break_page
            top = @box.section_bottom
            child = span_box(top, offset, span_width)
          end
        }
        @flow.run_bounding_box(child, :truncate, relocate, &block)
        @box.start_section(top + child.height)
        @placed_on_page = true if child.height > 0
        child
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

        page.move_to(left, top)
        page.line_to(right, top)
        page.line_to(right, bottom)
        page.line_to(left, bottom)
        page.line_to(left, top)
        page.stroke
      end

      private def settle_below(child : Layout::BoundingBox) : Nil
        super
        @placed_on_page = true
      end

      private def span_box(top : Float64, offset : Float64, span_width : Float64) : Layout::BoundingBox
        Layout::BoundingBox.new(
          x: @box.absolute_left + offset,
          y: @box.absolute_top - top,
          box_width: span_width,
          parent: @box,
        )
      end

      # Moves to the next column, or to a new page after the last column.
      # Returns `false` when the box is full and no page break is possible.
      private def next_column : Bool
        return true unless @box.advance_column
        return false unless @page_break && @placed_on_page

        break_page
        true
      end

      # Continues the box on a new page and runs the page break hooks.
      private def break_page : Nil
        @flow.start_new_page
        @box.start_new_page
        @placed_on_page = false
        @page_break_hooks.each(&.call(self))
      end
    end
  end
end
