module PDF
  module SVG
    # Represents a single path command (M, L, C, Q, Z, etc.)
    record PathCommand,
      type : Char,
      args : Array(Float64) = [] of Float64

    # Parses SVG path data (the "d" attribute) into a sequence of
    # absolute path commands.
    #
    # Supports: M, L, H, V, C, S, Q, T, A, Z (both upper and lower case).
    #
    # Ported from Prawn::SVG::Elements::Path.
    module PathParser
      # Parses a path data string into an array of absolute PathCommands.
      def self.parse(data : String) : Array(PathCommand)
        commands = [] of PathCommand
        return commands if data.empty?

        tokens = tokenize(data)
        return commands if tokens.empty?

        current_x = 0.0
        current_y = 0.0
        subpath_start_x = 0.0
        subpath_start_y = 0.0
        last_control_x = 0.0
        last_control_y = 0.0
        last_command = ' '

        i = 0
        while i < tokens.size
          token = tokens[i]

          if token.is_a?(Char)
            last_command = token
            i += 1
          elsif last_command == ' '
            break # no command yet
          end

          relative = last_command.lowercase?
          cmd = last_command.upcase

          case cmd
          when 'M'
            x, y = consume_pair(tokens, i)
            i += 2
            if relative
              x += current_x
              y += current_y
            end
            commands << PathCommand.new('M', [x, y])
            current_x = x
            current_y = y
            subpath_start_x = x
            subpath_start_y = y
            # Subsequent coordinates are treated as line-to
            last_command = relative ? 'l' : 'L'

          when 'L'
            x, y = consume_pair(tokens, i)
            i += 2
            if relative
              x += current_x
              y += current_y
            end
            commands << PathCommand.new('L', [x, y])
            current_x = x
            current_y = y

          when 'H'
            x = consume_number(tokens, i)
            i += 1
            x += current_x if relative
            commands << PathCommand.new('L', [x, current_y])
            current_x = x

          when 'V'
            y = consume_number(tokens, i)
            i += 1
            y += current_y if relative
            commands << PathCommand.new('L', [current_x, y])
            current_y = y

          when 'C'
            x1, y1 = consume_pair(tokens, i)
            i += 2
            x2, y2 = consume_pair(tokens, i)
            i += 2
            x, y = consume_pair(tokens, i)
            i += 2
            if relative
              x1 += current_x; y1 += current_y
              x2 += current_x; y2 += current_y
              x += current_x; y += current_y
            end
            commands << PathCommand.new('C', [x1, y1, x2, y2, x, y])
            last_control_x = x2
            last_control_y = y2
            current_x = x
            current_y = y

          when 'S'
            x2, y2 = consume_pair(tokens, i)
            i += 2
            x, y = consume_pair(tokens, i)
            i += 2
            if relative
              x2 += current_x; y2 += current_y
              x += current_x; y += current_y
            end
            # Reflect the last control point
            x1 = 2 * current_x - last_control_x
            y1 = 2 * current_y - last_control_y
            commands << PathCommand.new('C', [x1, y1, x2, y2, x, y])
            last_control_x = x2
            last_control_y = y2
            current_x = x
            current_y = y

          when 'Q'
            cx, cy = consume_pair(tokens, i)
            i += 2
            x, y = consume_pair(tokens, i)
            i += 2
            if relative
              cx += current_x; cy += current_y
              x += current_x; y += current_y
            end
            # Convert quadratic to cubic
            cp1x = current_x + 2.0/3.0 * (cx - current_x)
            cp1y = current_y + 2.0/3.0 * (cy - current_y)
            cp2x = x + 2.0/3.0 * (cx - x)
            cp2y = y + 2.0/3.0 * (cy - y)
            commands << PathCommand.new('C', [cp1x, cp1y, cp2x, cp2y, x, y])
            last_control_x = cx
            last_control_y = cy
            current_x = x
            current_y = y

          when 'T'
            x, y = consume_pair(tokens, i)
            i += 2
            if relative
              x += current_x
              y += current_y
            end
            cx = 2 * current_x - last_control_x
            cy = 2 * current_y - last_control_y
            cp1x = current_x + 2.0/3.0 * (cx - current_x)
            cp1y = current_y + 2.0/3.0 * (cy - current_y)
            cp2x = x + 2.0/3.0 * (cx - x)
            cp2y = y + 2.0/3.0 * (cy - y)
            commands << PathCommand.new('C', [cp1x, cp1y, cp2x, cp2y, x, y])
            last_control_x = cx
            last_control_y = cy
            current_x = x
            current_y = y

          when 'A'
            rx = consume_number(tokens, i); i += 1
            ry = consume_number(tokens, i); i += 1
            x_rotation = consume_number(tokens, i); i += 1
            large_arc = consume_number(tokens, i).to_i; i += 1
            sweep = consume_number(tokens, i).to_i; i += 1
            x, y = consume_pair(tokens, i); i += 2
            if relative
              x += current_x
              y += current_y
            end
            # Approximate arc with line for simplicity
            # A full arc-to-bezier implementation would be much more complex
            commands << PathCommand.new('L', [x, y])
            current_x = x
            current_y = y

          when 'Z'
            commands << PathCommand.new('Z')
            current_x = subpath_start_x
            current_y = subpath_start_y
          else
            i += 1 # skip unknown
          end
        end

        commands
      end

      private def self.tokenize(data : String) : Array(Char | Float64)
        tokens = [] of Char | Float64
        i = 0
        while i < data.size
          c = data[i]
          if c.letter?
            tokens << c
            i += 1
          elsif c == '-' || c == '+' || c == '.' || c.ascii_number?
            # Parse a number
            start = i
            i += 1 if c == '-' || c == '+'
            has_dot = (c == '.')
            while i < data.size
              nc = data[i]
              if nc.ascii_number?
                i += 1
              elsif nc == '.' && !has_dot
                has_dot = true
                i += 1
              elsif (nc == 'e' || nc == 'E') && i + 1 < data.size
                i += 1
                i += 1 if i < data.size && (data[i] == '+' || data[i] == '-')
              else
                break
              end
            end
            num_str = data[start...i]
            if num = num_str.to_f?
              tokens << num
            end
          else
            i += 1 # skip whitespace, commas
          end
        end
        tokens
      end

      private def self.consume_pair(tokens : Array(Char | Float64), index : Int32) : Tuple(Float64, Float64)
        x = consume_number(tokens, index)
        y = consume_number(tokens, index + 1)
        {x, y}
      end

      private def self.consume_number(tokens : Array(Char | Float64), index : Int32) : Float64
        return 0.0 if index >= tokens.size
        token = tokens[index]
        token.is_a?(Float64) ? token : 0.0
      end
    end
  end
end
