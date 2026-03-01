module PDF
  module Text
    module Formatted
      # Implements line wrapping for formatted text. Works in conjunction
      # with `Arranger` to determine how much text fits on a single line
      # within a given width.
      #
      # Ported from Prawn::Text::Formatted::LineWrap.
      class LineWrap
        # The accumulated width of the current line in points.
        getter accumulated_width : Float64 = 0.0

        # The number of spaces in the last wrapped line.
        getter space_count : Int32 = 0

        # Whether a newline was encountered during wrapping.
        getter? newline_encountered : Bool = false

        def initialize
          @accumulated_width = 0.0
          @space_count = 0
          @newline_encountered = false
          @line_empty = true
          @line_contains_more_than_one_word = false
          @line_full = false
          @fragment_output = ""
          @width = 0.0
        end

        # Returns the width of the last wrapped line.
        def width : Float64
          @accumulated_width
        end

        # Whether this line is the last line in the paragraph.
        def paragraph_finished?(arranger : Arranger) : Bool
          @newline_encountered || arranger.finished?
        end

        # Tokenize a fragment string into segments suitable for line wrapping.
        # Splits on whitespace boundaries and hyphens.
        def tokenize(fragment : String) : Array(String)
          tokens = [] of String
          current = String::Builder.new

          fragment.each_char_with_index do |char, i|
            if char == ' ' || char == '\t'
              # Flush current token if any
              unless current.empty?
                tokens << current.to_s
                current = String::Builder.new
              end
              # Collect consecutive whitespace
              ws = String::Builder.new
              ws << char
              # Peek ahead for more whitespace
              j = i + 1
              while j < fragment.size
                next_char = fragment[j]
                if next_char == ' ' || next_char == '\t'
                  ws << next_char
                  j += 1
                else
                  break
                end
              end
              tokens << ws.to_s if ws.@bytesize > 0
            elsif char == '-'
              current << char
              tokens << current.to_s
              current = String::Builder.new
            else
              current << char
            end
          end

          unless current.empty?
            tokens << current.to_s
          end

          tokens
        end

        # Wraps a single line of text. Returns the text that was placed on
        # this line. The arranger is updated with consumed/unconsumed state.
        def wrap_line(*, arranger : Arranger, width : Float64, font_measurer : FontMeasurer) : String
          initialize_line(width: width, arranger: arranger)

          while (fragment = arranger.next_string)
            @fragment_output = ""

            # Strip leading whitespace on the first fragment of a line
            if @line_empty && @accumulated_width == 0.0 && fragment != "\n"
              fragment = fragment.lstrip
            end

            # Skip empty fragments that precede a newline
            if @line_empty && fragment.empty? && arranger.preview_next_string == "\n"
              arranger.update_last_string("", "")
              next
            end

            unless add_fragment_to_line(fragment, arranger, font_measurer)
              break
            end
          end

          arranger.finalize_line(font_measurer)
          @accumulated_width = arranger.line_width
          @space_count = arranger.space_count
          arranger.line
        end

        private def add_fragment_to_line(fragment : String, arranger : Arranger, font_measurer : FontMeasurer) : Bool
          case fragment
          when ""
            true
          when "\n"
            @newline_encountered = true
            @line_empty = false
            arranger.update_last_string("", "")
            false
          else
            tokens = tokenize(fragment)
            tokens.each do |segment|
              segment_width = font_measurer.measure_width(segment, arranger.current_format_state)

              if @accumulated_width + segment_width <= @width
                @accumulated_width += segment_width
                @fragment_output += segment
              else
                # Line is full
                if @accumulated_width == 0.0 && !@line_contains_more_than_one_word
                  # Try character-level wrapping for the first word
                  wrap_by_char(segment, arranger, font_measurer)
                end
                @line_full = true
                finish_fragment(fragment, arranger)
                return false
              end
            end

            finish_fragment(fragment, arranger)
            update_line_status
            true
          end
        end

        private def finish_fragment(fragment : String, arranger : Arranger) : Nil
          remaining = if @fragment_output.size < fragment.size
                        fragment[@fragment_output.size..]
                      else
                        ""
                      end
          arranger.update_last_string(@fragment_output, remaining)
          @line_empty = false if !@fragment_output.empty?
        end

        private def initialize_line(*, width : Float64, arranger : Arranger) : Nil
          @width = width
          @accumulated_width = 0.0
          @line_empty = true
          @line_contains_more_than_one_word = false
          @newline_encountered = false
          @line_full = false
          @fragment_output = ""
          arranger.initialize_line
        end

        private def update_line_status : Nil
          if @fragment_output.includes?(' ') || @fragment_output.includes?('\t') ||
             @fragment_output.includes?('-')
            @line_contains_more_than_one_word = true
          end
        end

        private def wrap_by_char(segment : String, arranger : Arranger, font_measurer : FontMeasurer) : Nil
          segment.each_char do |char|
            char_str = char.to_s
            char_width = font_measurer.measure_width(char_str, arranger.current_format_state)
            if @accumulated_width + char_width <= @width
              @accumulated_width += char_width
              @fragment_output += char_str
            else
              break
            end
          end
        end
      end
    end
  end
end
