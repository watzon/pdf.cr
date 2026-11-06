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
          start = @pos
          i = @pos
          i += 1 if i < @data.size && (@data[i] == '-' || @data[i] == '+')
          int_start = i
          while i < @data.size && @data[i].ascii_number?
            i += 1
          end
          digits = i - int_start
          if i < @data.size && @data[i] == '.'
            i += 1
            frac_start = i
            while i < @data.size && @data[i].ascii_number?
              i += 1
            end
            digits += i - frac_start
          end
          return if digits == 0
          if i < @data.size && (@data[i] == 'e' || @data[i] == 'E')
            j = i + 1
            j += 1 if j < @data.size && (@data[j] == '-' || @data[j] == '+')
            if j < @data.size && @data[j].ascii_number?
              while j < @data.size && @data[j].ascii_number?
                j += 1
              end
              i = j
            end
          end
          value = @data[start...i].to_f?
          return unless value
          @pos = i
          value
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

      # Parses a path data string into an array of absolute PathCommands.
      def self.parse(data : String) : Array(PathCommand)
        commands = [] of PathCommand
        scanner = Scanner.new(data)

        cx = 0.0
        cy = 0.0
        start_x = 0.0
        start_y = 0.0
        prev_cubic : Tuple(Float64, Float64)? = nil
        prev_quad : Tuple(Float64, Float64)? = nil
        cmd : Char? = nil

        until scanner.eof?
          c = scanner.peek
          if c.letter?
            up = c.upcase
            break unless up == 'Z' || ARITY.has_key?(up)
            cmd = c
            scanner.advance
          else
            # Implicit repeat of the previous command. Not allowed after Z.
            break if cmd.nil? || cmd.upcase == 'Z'
            break unless scanner.number_start?
          end

          letter = cmd || break
          up = letter.upcase
          relative = letter.lowercase?

          if up == 'Z'
            commands << PathCommand.new('Z')
            cx = start_x
            cy = start_y
            prev_cubic = nil
            prev_quad = nil
            next
          end

          args = read_args(scanner, up) || break
          new_cubic : Tuple(Float64, Float64)? = nil
          new_quad : Tuple(Float64, Float64)? = nil

          case up
          when 'M'
            x, y = args[0], args[1]
            x += cx if relative
            y += cy if relative
            commands << PathCommand.new('M', [x, y])
            cx, cy = x, y
            start_x, start_y = x, y
            cmd = relative ? 'l' : 'L'
          when 'L'
            x, y = args[0], args[1]
            x += cx if relative
            y += cy if relative
            commands << PathCommand.new('L', [x, y])
            cx, cy = x, y
          when 'H'
            x = relative ? args[0] + cx : args[0]
            commands << PathCommand.new('L', [x, cy])
            cx = x
          when 'V'
            y = relative ? args[0] + cy : args[0]
            commands << PathCommand.new('L', [cx, y])
            cy = y
          when 'C', 'S'
            if up == 'C'
              x1, y1, x2, y2, x, y = args[0], args[1], args[2], args[3], args[4], args[5]
              if relative
                x1 += cx; y1 += cy
              end
            else
              x2, y2, x, y = args[0], args[1], args[2], args[3]
              if pc = prev_cubic
                x1 = 2 * cx - pc[0]
                y1 = 2 * cy - pc[1]
              else
                x1, y1 = cx, cy
              end
            end
            if relative
              x2 += cx; y2 += cy
              x += cx; y += cy
            end
            commands << PathCommand.new('C', [x1, y1, x2, y2, x, y])
            new_cubic = {x2, y2}
            cx, cy = x, y
          when 'Q', 'T'
            if up == 'Q'
              qx, qy, x, y = args[0], args[1], args[2], args[3]
              if relative
                qx += cx; qy += cy
              end
            else
              x, y = args[0], args[1]
              if pq = prev_quad
                qx = 2 * cx - pq[0]
                qy = 2 * cy - pq[1]
              else
                qx, qy = cx, cy
              end
            end
            if relative
              x += cx; y += cy
            end
            commands << PathCommand.new('C', [
              cx + 2.0/3.0 * (qx - cx), cy + 2.0/3.0 * (qy - cy),
              x + 2.0/3.0 * (qx - x), y + 2.0/3.0 * (qy - y), x, y,
            ])
            new_quad = {qx, qy}
            cx, cy = x, y
          when 'A'
            x, y = args[5], args[6]
            x += cx if relative
            y += cy if relative
            arc_to_curves(cx, cy, args[0], args[1], args[2], args[3] != 0.0, args[4] != 0.0, x, y, commands)
            cx, cy = x, y
          end

          prev_cubic = new_cubic
          prev_quad = new_quad
        end

        commands
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
      private def self.arc_to_curves(
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

        lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1.0
          scale = Math.sqrt(lambda)
          rx *= scale
          ry *= scale
        end

        rx2 = rx * rx
        ry2 = ry * ry
        num = rx2 * ry2 - rx2 * y1p * y1p - ry2 * x1p * x1p
        den = rx2 * y1p * y1p + ry2 * x1p * x1p
        coef = den == 0.0 ? 0.0 : Math.sqrt({num / den, 0.0}.max)
        coef = -coef if large_arc == sweep
        cxp = coef * (rx * y1p / ry)
        cyp = coef * -(ry * x1p / rx)

        center_x = cos_phi * cxp - sin_phi * cyp + (x1 + x2) / 2.0
        center_y = sin_phi * cxp + cos_phi * cyp + (y1 + y2) / 2.0

        theta1 = Math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx)
        theta2 = Math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx)
        dtheta = theta2 - theta1
        dtheta -= 2 * Math::PI if !sweep && dtheta > 0
        dtheta += 2 * Math::PI if sweep && dtheta < 0

        segments = (dtheta.abs / (Math::PI / 2) - 1e-9).ceil.to_i
        segments = 1 if segments < 1
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
    end
  end
end
