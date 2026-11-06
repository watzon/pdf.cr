module PDF
  module SVG
    # A parsed `preserveAspectRatio` value.
    #
    # Maps a viewBox into a viewport: uniform scale with `meet` (fit inside)
    # or `slice` (cover), aligned by xMin/xMid/xMax and yMin/yMid/yMax, or a
    # non-uniform stretch with `none`. Invalid values give the SVG default
    # `xMidYMid meet`.
    struct AspectRatio
      ALIGN_FACTORS = {"min" => 0.0, "mid" => 0.5, "max" => 1.0}

      # Alignment of the scaled viewBox in the viewport (0, 0.5 or 1).
      getter align_x : Float64
      getter align_y : Float64

      # True for `slice`, false for `meet`.
      getter? slice : Bool

      # True for `none` (non-uniform scaling).
      getter? none : Bool

      def initialize(@align_x : Float64 = 0.5, @align_y : Float64 = 0.5, @slice : Bool = false, @none : Bool = false)
      end

      def self.parse(value : String?) : AspectRatio
        return new unless value

        parts = value.strip.split(/\s+/)
        parts.shift if parts.first? == "defer"
        align = parts[0]?
        mode = parts[1]?
        return new unless align
        return new unless mode.nil? || mode == "meet" || mode == "slice"
        return new(none: true) if align == "none"

        match = align.match(/\Ax(Min|Mid|Max)Y(Min|Mid|Max)\z/)
        return new unless match

        new(ALIGN_FACTORS[match[1].downcase], ALIGN_FACTORS[match[2].downcase], slice: mode == "slice")
      end

      # Returns the matrix that maps the viewBox {min_x, min_y, width,
      # height} into the viewport rectangle at (x, y) of the given size.
      def transform(viewbox : Tuple(Float64, Float64, Float64, Float64), x : Float64, y : Float64, width : Float64, height : Float64) : Transform::Matrix
        min_x, min_y, vb_w, vb_h = viewbox
        sx = width / vb_w
        sy = height / vb_h
        unless none?
          sx = sy = slice? ? {sx, sy}.max : {sx, sy}.min
        end

        tx = x + (width - vb_w * sx) * @align_x - min_x * sx
        ty = y + (height - vb_h * sy) * @align_y - min_y * sy
        {sx, 0.0, 0.0, sy, tx, ty}
      end
    end
  end
end
