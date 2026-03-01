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
    # col_box.column_width  # => 244.0
    # col_box.current_column  # => 0
    # ```
    class ColumnBox < BoundingBox
      # Number of columns
      getter columns : Int32

      # Space between columns in points
      getter spacer : Float64

      # Current column index (0-based)
      getter current_column : Int32 = 0

      def initialize(
        x : Float64,
        y : Float64,
        width : Float64,
        height : Float64? = nil,
        parent : BoundingBox? = nil,
        @columns : Int32 = 2,
        @spacer : Float64 = 12.0
      )
        super(x: x, y: y, box_width: width, fixed_height: height, parent: parent)
        @current_column = 0
      end

      # The bare column width before padding.
      def bare_column_width : Float64
        (@box_width - (@spacer * (@columns - 1))) / @columns
      end

      # The column width after padding. Used for text line length.
      def width : Float64
        bare_column_width - (@total_left_padding + @total_right_padding)
      end

      # Column width including the spacer.
      def width_of_column : Float64
        bare_column_width + @spacer
      end

      # Absolute left x-coordinate of the current column.
      def left_side : Float64
        absolute_left + (width_of_column * @current_column)
      end

      # Relative left position of the current column.
      def left : Float64
        width_of_column * @current_column
      end

      # Absolute right x-coordinate of the current column.
      def right_side : Float64
        columns_from_right = @columns - (1 + @current_column)
        absolute_right - (width_of_column * columns_from_right)
      end

      # Relative right position of the current column.
      def right : Float64
        left + width
      end

      # Advances to the next column. Returns true if a new page is needed.
      def advance_column : Bool
        @current_column = (@current_column + 1) % @columns
        @cursor_y = 0.0
        @current_column == 0 # true means we wrapped around -> new page needed
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
