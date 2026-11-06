module PDF
  module SVG
    # Represents a single path command (M, L, C or Z)
    record PathCommand,
      type : Char,
      args : Array(Float64) = [] of Float64

    # Parses SVG path data (the "d" attribute) into a sequence of
    # absolute path commands (M, L, C, Z).
    #
    # Supports: M, L, H, V, C, S, Q, T, A, Z (both upper and lower case).
    # H and V become L, S/Q/T become C, and arcs become cubic curves
    # (SVG 1.1 implementation notes F.6.5, segments of at most 90 degrees).
    #
    # Malformed input never raises and never loops: parsing stops at the
    # first token that does not fit the grammar, and commands with missing
    # arguments are dropped.
    #
    # Ported from Prawn::SVG::Elements::Path.
    module PathParser
      # Cursor over the path string. Number and flag readers restore the
      # position when they fail.
      private class Scanner
        getter pos = 0

        def initialize(@data : String)
        end

        def eof? : Bool
          skip_separators
          @pos >= @data.size
        end

        def peek : Char
          @data[@pos]
        end

        def advance : Nil
          @pos += 1
        end

        def skip_separators : Nil
          while @pos < @data.size && (@data[@pos].whitespace? || @data[@pos] == ',')
            @pos += 1
          end
        end

        def number_start? : Bool
          return false if eof?
          c = peek
          c.ascii_number? || c == '.' || c == '-' || c == '+'
        end

        def read_number : Float64?
          skip_separators
          i = skip_sign(@pos)
          int_end = scan_digits(i)
          digits = int_end - i
          i = int_end
          if i < @data.size && @data[i] == '.'
            frac_end = scan_digits(i + 1)
            digits += frac_end - (i + 1)
            i = frac_end
          end
          return if digits == 0
          i = scan_exponent(i)
          value = @data[@pos...i].to_f?
          return unless value
          @pos = i
          value
        end

        private def skip_sign(i : Int32) : Int32
          i < @data.size && (@data[i] == '-' || @data[i] == '+') ? i + 1 : i
        end

        private def scan_digits(i : Int32) : Int32
          while i < @data.size && @data[i].ascii_number?
            i += 1
          end
          i
        end

        # Returns the index after an exponent starting at `i`, or `i` itself
        # when there is no complete exponent.
        private def scan_exponent(i : Int32) : Int32
          return i unless i < @data.size && (@data[i] == 'e' || @data[i] == 'E')
          j = skip_sign(i + 1)
          return i unless j < @data.size && @data[j].ascii_number?
          scan_digits(j)
        end

        # Arc flags are a single '0' or '1' and may touch the next number.
        def read_flag : Float64?
          skip_separators
          return if @pos >= @data.size
          case @data[@pos]
          when '0' then @pos += 1; 0.0
          when '1' then @pos += 1; 1.0
          end
        end
      end

      # Number of arguments per command letter.
      private ARITY = {
        'M' => 2, 'L' => 2, 'H' => 1, 'V' => 1, 'C' => 6,
        'S' => 4, 'Q' => 4, 'T' => 2, 'A' => 7,
      }

      # Per-path state: current point, subpath start, the previous curve
      # control points (for S and T) and the emitted commands.
      private class Builder
        getter commands = [] of PathCommand
        @cx = 0.0
        @cy = 0.0
        @start_x = 0.0
        @start_y = 0.0
        @prev_cubic : Tuple(Float64, Float64)? = nil
        @prev_quad : Tuple(Float64, Float64)? = nil

        def close : Nil
          @commands << PathCommand.new('Z')
          @cx = @start_x
          @cy = @start_y
          @prev_cubic = nil
          @prev_quad = nil
        end

        def move_to(args : Array(Float64), relative : Bool) : Nil
          x, y = target(args[0], args[1], relative)
          @commands << PathCommand.new('M', [x, y])
          @start_x, @start_y = x, y
          finish(x, y)
        end

        def line_to(args : Array(Float64), relative : Bool) : Nil
          x, y = target(args[0], args[1], relative)
          @commands << PathCommand.new('L', [x, y])
          finish(x, y)
        end

        def horizontal(args : Array(Float64), relative : Bool) : Nil
          x = relative ? args[0] + @cx : args[0]
          @commands << PathCommand.new('L', [x, @cy])
          finish(x, @cy)
        end

        def vertical(args : Array(Float64), relative : Bool) : Nil
          y = relative ? args[0] + @cy : args[0]
          @commands << PathCommand.new('L', [@cx, y])
          finish(@cx, y)
        end

        def cubic(args : Array(Float64), relative : Bool, smooth : Bool) : Nil
          if smooth
            x1, y1 = reflect(@prev_cubic)
            x2, y2 = target(args[0], args[1], relative)
            x, y = target(args[2], args[3], relative)
          else
            x1, y1 = target(args[0], args[1], relative)
            x2, y2 = target(args[2], args[3], relative)
            x, y = target(args[4], args[5], relative)
          end
          @commands << PathCommand.new('C', [x1, y1, x2, y2, x, y])
          finish(x, y, cubic: {x2, y2})
        end

        def quadratic(args : Array(Float64), relative : Bool, smooth : Bool) : Nil
          if smooth
            qx, qy = reflect(@prev_quad)
            x, y = target(args[0], args[1], relative)
          else
            qx, qy = target(args[0], args[1], relative)
            x, y = target(args[2], args[3], relative)
          end
          @commands << PathCommand.new('C', [
            @cx + 2.0/3.0 * (qx - @cx), @cy + 2.0/3.0 * (qy - @cy),
            x + 2.0/3.0 * (qx - x), y + 2.0/3.0 * (qy - y), x, y,
          ])
          finish(x, y, quad: {qx, qy})
        end

        def arc(args : Array(Float64), relative : Bool) : Nil
          x, y = target(args[5], args[6], relative)
          PathParser.arc_to_curves(@cx, @cy, args[0], args[1], args[2], args[3] != 0.0, args[4] != 0.0, x, y, @commands)
          finish(x, y)
        end

        # Resolves a coordinate pair against the current point.
        private def target(x : Float64, y : Float64, relative : Bool) : Tuple(Float64, Float64)
          relative ? {x + @cx, y + @cy} : {x, y}
        end

        # Reflects the previous control point about the current point, or
        # returns the current point when there is none.
        private def reflect(prev : Tuple(Float64, Float64)?) : Tuple(Float64, Float64)
          prev ? {2 * @cx - prev[0], 2 * @cy - prev[1]} : {@cx, @cy}
        end

        private def finish(x : Float64, y : Float64, cubic : Tuple(Float64, Float64)? = nil, quad : Tuple(Float64, Float64)? = nil) : Nil
          @cx, @cy = x, y
          @prev_cubic = cubic
          @prev_quad = quad
        end
      end

      # Parses a path data string into an array of absolute PathCommands.
      def self.parse(data : String) : Array(PathCommand)
        builder = Builder.new
        scanner = Scanner.new(data)
        cmd : Char? = nil

        until scanner.eof?
          letter = next_command(scanner, cmd) || break
          cmd = letter
          up = letter.upcase
          relative = letter.lowercase?

          if up == 'Z'
            builder.close
            next
          end

          args = read_args(scanner, up) || break
          dispatch(builder, up, relative, args)
          cmd = relative ? 'l' : 'L' if up == 'M'
        end

        builder.commands
      end

      # Reads the next command letter, or returns the previous command for an
      # implicit repeat. Returns nil when parsing must stop.
      private def self.next_command(scanner : Scanner, previous : Char?) : Char?
        c = scanner.peek
        if c.letter?
          up = c.upcase
          return unless up == 'Z' || ARITY.has_key?(up)
          scanner.advance
          c
        else
          # Implicit repeat of the previous command. Not allowed after Z.
          return if previous.nil? || previous.upcase == 'Z'
          previous if scanner.number_start?
        end
      end

      private def self.dispatch(builder : Builder, up : Char, relative : Bool, args : Array(Float64)) : Nil
        case up
        when 'M' then builder.move_to(args, relative)
        when 'L' then builder.line_to(args, relative)
        when 'H' then builder.horizontal(args, relative)
        when 'V' then builder.vertical(args, relative)
        when 'C' then builder.cubic(args, relative, smooth: false)
        when 'S' then builder.cubic(args, relative, smooth: true)
        when 'Q' then builder.quadratic(args, relative, smooth: false)
        when 'T' then builder.quadratic(args, relative, smooth: true)
        when 'A' then builder.arc(args, relative)
        end
      end

      private def self.read_args(scanner : Scanner, up : Char) : Array(Float64)?
        count = ARITY[up]
        args = Array(Float64).new(count)
        count.times do |k|
          is_flag = up == 'A' && (k == 3 || k == 4)
          value = is_flag ? scanner.read_flag : scanner.read_number
          return unless value
          args << value
        end
        args
      end

      # Appends the cubic approximation of an SVG elliptical arc
      # (SVG 1.1 implementation notes F.6.5 and F.6.6).
      # :nodoc:
      def self.arc_to_curves(
        x1 : Float64, y1 : Float64, rx : Float64, ry : Float64, phi_deg : Float64,
        large_arc : Bool, sweep : Bool, x2 : Float64, y2 : Float64,
        commands : Array(PathCommand),
      ) : Nil
        return if x1 == x2 && y1 == y2
        rx = rx.abs
        ry = ry.abs
        if rx == 0.0 || ry == 0.0
          commands << PathCommand.new('L', [x2, y2])
          return
        end

        phi = phi_deg * Math::PI / 180.0
        cos_phi = Math.cos(phi)
        sin_phi = Math.sin(phi)

        dx = (x1 - x2) / 2.0
        dy = (y1 - y2) / 2.0
        x1p = cos_phi * dx + sin_phi * dy
        y1p = -sin_phi * dx + cos_phi * dy

        rx, ry = scale_radii(rx, ry, x1p, y1p)
        cxp, cyp = arc_center_offset(rx, ry, x1p, y1p, large_arc == sweep)

        center_x = cos_phi * cxp - sin_phi * cyp + (x1 + x2) / 2.0
        center_y = sin_phi * cxp + cos_phi * cyp + (y1 + y2) / 2.0

        theta1 = Math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx)
        theta2 = Math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx)
        dtheta = theta2 - theta1
        dtheta -= 2 * Math::PI if !sweep && dtheta > 0
        dtheta += 2 * Math::PI if sweep && dtheta < 0

        segments = {(dtheta.abs / (Math::PI / 2) - 1e-9).ceil.to_i, 1}.max
        delta = dtheta / segments
        t = 4.0 / 3.0 * Math.tan(delta / 4.0)

        point = ->(a : Float64) {
          {center_x + rx * Math.cos(a) * cos_phi - ry * Math.sin(a) * sin_phi,
           center_y + rx * Math.cos(a) * sin_phi + ry * Math.sin(a) * cos_phi}
        }
        deriv = ->(a : Float64) {
          {-rx * Math.sin(a) * cos_phi - ry * Math.cos(a) * sin_phi,
           -rx * Math.sin(a) * sin_phi + ry * Math.cos(a) * cos_phi}
        }

        segments.times do |k|
          a1 = theta1 + k * delta
          a2 = a1 + delta
          p1 = point.call(a1)
          p2 = point.call(a2)
          d1 = deriv.call(a1)
          d2 = deriv.call(a2)
          ex, ey = k == segments - 1 ? {x2, y2} : p2
          commands << PathCommand.new('C', [
            p1[0] + t * d1[0], p1[1] + t * d1[1],
            p2[0] - t * d2[0], p2[1] - t * d2[1], ex, ey,
          ])
        end
      end

      # Scales the radii up when they are too small to span the endpoints.
      private def self.scale_radii(rx : Float64, ry : Float64, x1p : Float64, y1p : Float64) : Tuple(Float64, Float64)
        lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        return {rx, ry} unless lambda > 1.0
        scale = Math.sqrt(lambda)
        {rx * scale, ry * scale}
      end

      # Center of the arc in the rotated frame (F.6.5.2). `negate` is true
      # when the large-arc and sweep flags are equal.
      private def self.arc_center_offset(rx : Float64, ry : Float64, x1p : Float64, y1p : Float64, negate : Bool) : Tuple(Float64, Float64)
        rx2 = rx * rx
        ry2 = ry * ry
        num = rx2 * ry2 - rx2 * y1p * y1p - ry2 * x1p * x1p
        den = rx2 * y1p * y1p + ry2 * x1p * x1p
        coef = den == 0.0 ? 0.0 : Math.sqrt({num / den, 0.0}.max)
        coef = -coef if negate
        {coef * (rx * y1p / ry), coef * -(ry * x1p / rx)}
      end
    end
  end
end
