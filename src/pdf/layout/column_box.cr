module PDF
  module Layout
    # A column box extends BoundingBox to flow content across multiple
    # columns on the same page before moving to the next page.
    #
    # Ported from Prawn::Document::ColumnBox.
    #
    # ```
    # col_box = ColumnBox.new(
    #   x: 50.0, y: 700.0,
    #   width: 500.0, height: 600.0,
    #   columns: 2, spacer: 12.0,
    # )
    # col_box.column_width   # => 244.0
    # col_box.current_column # => 0
    # ```
    class ColumnBox < BoundingBox
      # Number of columns
      getter columns : Int32

      # Space between columns in points
      getter spacer : Float64

      # Current column index (0-based)
      getter current_column : Int32 = 0

      # True once the last column is full.
      getter? full : Bool = false

      # Offset from the top of the box where the columns of the current
      # section start. It is 0 until a full-width span pushes it down.
      getter column_top : Float64 = 0.0

      # The largest cursor offset (from the top of the box) that any column
      # of the current section has used. A span starts at this offset.
      getter section_bottom : Float64 = 0.0

      def initialize(
        x : Float64,
        y : Float64,
        width : Float64,
        height : Float64? = nil,
        parent : BoundingBox? = nil,
        @columns : Int32 = 2,
        @spacer : Float64 = 12.0,
      )
        super(x: x, y: y, box_width: width, fixed_height: height, parent: parent)
        @current_column = 0
      end

      # The bare column width, before per-column padding.
      def bare_column_width : Float64
        (@box_width - (@spacer * (@columns - 1))) / @columns
      end

      # Padding does not change the overall width of a column box.
      # It only narrows each column (see `width`).
      def add_left_padding(padding : Float64) : Nil
        @total_left_padding += padding
      end

      def add_right_padding(padding : Float64) : Nil
        @total_right_padding += padding
      end

      def subtract_left_padding(padding : Float64) : Nil
        @total_left_padding -= padding
      end

      def subtract_right_padding(padding : Float64) : Nil
        @total_right_padding -= padding
      end

      # The column width after padding. Used for text line length.
      def width : Float64
        bare_column_width - (@total_left_padding + @total_right_padding)
      end

      # Column width including the spacer.
      def width_of_column : Float64
        bare_column_width + @spacer
      end

      # Absolute left x-coordinate of the current column (after padding).
      def left_side : Float64
        absolute_left + (width_of_column * @current_column) + @total_left_padding
      end

      # Relative left position of the current column.
      def left : Float64
        width_of_column * @current_column
      end

      # Absolute right x-coordinate of the current column.
      def right_side : Float64
        left_side + width
      end

      # Relative right position of the current column.
      def right : Float64
        left + width
      end

      # Advances to the next column. Returns true when the last column is
      # already in use: the box is then marked `full?` and the caller must
      # start a new page. The column index never wraps around.
      def advance_column : Bool
        if @current_column >= @columns - 1
          @full = true
          return true
        end
        @current_column += 1
        @cursor_y = @column_top
        false
      end

      def move_down(amount : Float64) : Nil
        super
        track_section_bottom
      end

      def move_to(relative_y : Float64) : Nil
        super
        track_section_bottom
      end

      # Starts a new section of columns at `offset` from the top of the box.
      # All columns of the new section start at this offset, beginning with
      # the first column. Used after a full-width span.
      def start_section(offset : Float64) : Nil
        @current_column = 0
        @full = false
        @column_top = offset
        @section_bottom = offset
        @cursor_y = offset
        @stretched_height = Math.max(@stretched_height, offset) if stretchy?
      end

      # Resets the box for a new page: the first column, at the top of the
      # box, with no sections. The box keeps its position and size.
      def start_new_page : Nil
        start_section(0.0)
      end

      private def track_section_bottom : Nil
        @section_bottom = Math.max(@section_bottom, @cursor_y)
      end

      # Converts a relative point to absolute coordinates,
      # accounting for the current column offset.
      def to_absolute(point : Tuple(Float64, Float64)) : Tuple(Float64, Float64)
        {point[0] + left_side, absolute_top - point[1]}
      end

      # Returns the absolute y position of the cursor.
      def absolute_cursor_y : Float64
        @y - @cursor_y
      end
    end
  end
end
