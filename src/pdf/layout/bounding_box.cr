module PDF
  module Layout
    # A bounding box constrains content flow within a rectangular area.
    # It provides a local coordinate system and cursor management.
    #
    # Bounding boxes are positioned relative to their top-left corner.
    # Width is measured to the right, height is measured downward.
    #
    # Ported from Prawn::Document::BoundingBox.
    #
    # ```
    # box = BoundingBox.new(
    #   x: 50.0, y: 700.0,
    #   width: 400.0, height: 300.0,
    # )
    # box.cursor        # => 300.0 (top of the box)
    # box.move_down(20)
    # box.cursor        # => 280.0
    # ```
    class BoundingBox
      # Absolute x-coordinate of the top-left corner
      getter x : Float64

      # Absolute y-coordinate of the top-left corner
      getter y : Float64

      # Width of the bounding box in points
      getter box_width : Float64

      # Fixed height of the bounding box (nil for stretchy boxes)
      getter fixed_height : Float64?

      # Parent bounding box (for nesting)
      getter parent : BoundingBox?

      # Left padding accumulator
      property total_left_padding : Float64 = 0.0

      # Right padding accumulator
      property total_right_padding : Float64 = 0.0

      # Current cursor position (relative, measured from top)
      @cursor_y : Float64 = 0.0

      # Stretched height tracker (for stretchy boxes)
      @stretched_height : Float64 = 0.0

      def initialize(
        @x : Float64,
        @y : Float64,
        @box_width : Float64,
        @fixed_height : Float64? = nil,
        @parent : BoundingBox? = nil
      )
        @cursor_y = 0.0
        @stretched_height = 0.0
      end

      # The absolute bottom y-coordinate.
      def absolute_bottom : Float64
        @y - height
      end

      # Absolute bottom-left point.
      def absolute_bottom_left : Tuple(Float64, Float64)
        {absolute_left, absolute_bottom}
      end

      # Absolute bottom-right point.
      def absolute_bottom_right : Tuple(Float64, Float64)
        {absolute_right, absolute_bottom}
      end

      # Absolute left x-coordinate.
      def absolute_left : Float64
        @x
      end

      # Absolute right x-coordinate.
      def absolute_right : Float64
        @x + @box_width
      end

      # Absolute top y-coordinate.
      def absolute_top : Float64
        @y
      end

      # Absolute top-left point.
      def absolute_top_left : Tuple(Float64, Float64)
        {absolute_left, absolute_top}
      end

      # Absolute top-right point.
      def absolute_top_right : Tuple(Float64, Float64)
        {absolute_right, absolute_top}
      end

      # Increase the left padding.
      def add_left_padding(padding : Float64) : Nil
        @total_left_padding += padding
        @x += padding
        @box_width -= padding
      end

      # Increase the right padding.
      def add_right_padding(padding : Float64) : Nil
        @total_right_padding += padding
        @box_width -= padding
      end

      # The translated origin (x, y - height).
      def anchor : Tuple(Float64, Float64)
        {@x, @y - height}
      end

      # Relative bottom y-coordinate (always 0).
      def bottom : Float64
        0.0
      end

      # Relative bottom-left point.
      def bottom_left : Tuple(Float64, Float64)
        {left, bottom}
      end

      # Relative bottom-right point.
      def bottom_right : Tuple(Float64, Float64)
        {right, bottom}
      end

      # Current cursor position relative to the top of the box.
      # Starts at `height` and decreases as content is added.
      def cursor : Float64
        height - @cursor_y
      end

      # Height of the bounding box. For stretchy boxes, this is
      # calculated from the maximum cursor displacement.
      def height : Float64
        @fixed_height || @stretched_height
      end

      # Temporarily adjust padding for indentation.
      def indent(left_padding : Float64, right_padding : Float64 = 0.0, &) : Nil
        add_left_padding(left_padding)
        add_right_padding(right_padding)
        yield
      ensure
        subtract_left_padding(left_padding)
        subtract_right_padding(right_padding)
      end

      # Relative left x-coordinate (always 0).
      def left : Float64
        0.0
      end

      # Alias for absolute_left.
      def left_side : Float64
        absolute_left
      end

      # Move the cursor down by the given amount.
      def move_down(amount : Float64) : Nil
        @cursor_y += amount
        if @fixed_height.nil?
          @stretched_height = Math.max(@stretched_height, @cursor_y)
        end
      end

      # Move the cursor to a specific relative y position.
      def move_to(relative_y : Float64) : Nil
        @cursor_y = height - relative_y
        if @fixed_height.nil?
          @stretched_height = Math.max(@stretched_height, @cursor_y)
        end
      end

      # Whether this is a stretchy box (no fixed height).
      def stretchy? : Bool
        @fixed_height.nil?
      end

      # Relative right x-coordinate (equal to width).
      def right : Float64
        width
      end

      # Alias for absolute_right.
      def right_side : Float64
        absolute_right
      end

      # Decrease the left padding.
      def subtract_left_padding(padding : Float64) : Nil
        @total_left_padding -= padding
        @x -= padding
        @box_width += padding
      end

      # Decrease the right padding.
      def subtract_right_padding(padding : Float64) : Nil
        @total_right_padding -= padding
        @box_width += padding
      end

      # Relative top y-coordinate (equal to height).
      def top : Float64
        height
      end

      # Relative top-left point.
      def top_left : Tuple(Float64, Float64)
        {left, top}
      end

      # Relative top-right point.
      def top_right : Tuple(Float64, Float64)
        {right, top}
      end

      # Available width (already adjusted by padding operations).
      def width : Float64
        @box_width
      end

      # Converts a relative point to absolute coordinates.
      def to_absolute(point : Tuple(Float64, Float64)) : Tuple(Float64, Float64)
        {point[0] + absolute_left, absolute_top - point[1]}
      end

      # Returns the absolute y position of the cursor.
      def absolute_cursor_y : Float64
        @y - @cursor_y
      end
    end
  end
end
