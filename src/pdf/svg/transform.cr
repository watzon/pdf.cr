module PDF
  module SVG
    # Parses SVG transform attributes into a 2D transformation matrix.
    #
    # Supports: translate, scale, rotate, skewX, skewY, matrix.
    #
    # Ported from Prawn::SVG::TransformParser.
    module Transform
      # A 2D affine transformation matrix [a, b, c, d, e, f].
      # Represents the matrix:
      #   | a c e |
      #   | b d f |
      #   | 0 0 1 |
      alias Matrix = Tuple(Float64, Float64, Float64, Float64, Float64, Float64)

      IDENTITY = {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

      # Parses a transform attribute string into a combined matrix.
      def self.parse(transform_str : String?) : Matrix
        return IDENTITY unless transform_str
        transform_str = transform_str.strip
        return IDENTITY if transform_str.empty?

        result = IDENTITY

        # Match each transform function
        transform_str.scan(/(\w+)\s*\(([^)]*)\)/) do |match|
          func = match[1]
          args = match[2].split(/[\s,]+/).compact_map(&.to_f?)

          matrix = case func
                   when "translate"
                     parse_translate(args)
                   when "scale"
                     parse_scale(args)
                   when "rotate"
                     parse_rotate(args)
                   when "skewX"
                     parse_skew_x(args)
                   when "skewY"
                     parse_skew_y(args)
                   when "matrix"
                     parse_matrix(args)
                   else
                     IDENTITY
                   end

          result = multiply(result, matrix)
        end

        result
      end

      # Multiplies two transformation matrices.
      def self.multiply(m1 : Matrix, m2 : Matrix) : Matrix
        a1, b1, c1, d1, e1, f1 = m1
        a2, b2, c2, d2, e2, f2 = m2

        {
          a1 * a2 + c1 * b2,
          b1 * a2 + d1 * b2,
          a1 * c2 + c1 * d2,
          b1 * c2 + d1 * d2,
          a1 * e2 + c1 * f2 + e1,
          b1 * e2 + d1 * f2 + f1,
        }
      end

      # Applies a transformation matrix to a point.
      def self.apply(matrix : Matrix, x : Float64, y : Float64) : Tuple(Float64, Float64)
        a, b, c, d, e, f = matrix
        {a * x + c * y + e, b * x + d * y + f}
      end

      private def self.parse_translate(args : Array(Float64)) : Matrix
        tx = args[0]? || 0.0
        ty = args[1]? || 0.0
        {1.0, 0.0, 0.0, 1.0, tx, ty}
      end

      private def self.parse_scale(args : Array(Float64)) : Matrix
        sx = args[0]? || 1.0
        sy = args[1]? || sx
        {sx, 0.0, 0.0, sy, 0.0, 0.0}
      end

      private def self.parse_rotate(args : Array(Float64)) : Matrix
        angle = (args[0]? || 0.0) * Math::PI / 180.0
        cos_a = Math.cos(angle)
        sin_a = Math.sin(angle)

        rotation = {cos_a, sin_a, -sin_a, cos_a, 0.0, 0.0}

        if args.size >= 3
          cx = args[1]
          cy = args[2]
          # translate(cx, cy) * rotate(angle) * translate(-cx, -cy)
          t1 = {1.0, 0.0, 0.0, 1.0, cx, cy}
          t2 = {1.0, 0.0, 0.0, 1.0, -cx, -cy}
          multiply(multiply(t1, rotation), t2)
        else
          rotation
        end
      end

      private def self.parse_skew_x(args : Array(Float64)) : Matrix
        angle = (args[0]? || 0.0) * Math::PI / 180.0
        {1.0, 0.0, Math.tan(angle), 1.0, 0.0, 0.0}
      end

      private def self.parse_skew_y(args : Array(Float64)) : Matrix
        angle = (args[0]? || 0.0) * Math::PI / 180.0
        {1.0, Math.tan(angle), 0.0, 1.0, 0.0, 0.0}
      end

      private def self.parse_matrix(args : Array(Float64)) : Matrix
        return IDENTITY unless args.size >= 6
        {args[0], args[1], args[2], args[3], args[4], args[5]}
      end
    end
  end
end
