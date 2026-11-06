module PDF
  module Text
    module Formatted
      # A formatted text box that renders rich text within a bounded
      # rectangular area. Supports multiple fonts, styles, colors,
      # text alignment, and overflow control.
      #
      # Ported from Prawn::Text::Formatted::Box.
      #
      # ```
      # box = Box.new(
      #   formatted_text: [
      #     {text: "Hello ", styles: [] of Symbol},
      #     {text: "world", styles: [:bold]},
      #   ],
      #   at: {50.0, 700.0},
      #   width: 400.0,
      #   height: 200.0,
      #   align: :left,
      #   overflow: :truncate,
      #   document: doc,
      # )
      # remaining = box.render(page)
      # ```
      class Box
        # Position of the upper-left corner of the box
        getter at : Tuple(Float64, Float64)

        # Width of the box in points
        getter width : Float64

        # Height of the box in points
        getter height : Float64

        # Text alignment (:left, :center, :right, :justify)
        getter align : Symbol

        # Overflow behavior:
        # - `:truncate` stops rendering when the height is used up (default)
        # - `:expand` ignores the height limit and renders all text
        # - `:shrink_to_fit` reduces the font size in 0.5pt steps (down to
        #   `MIN_SHRINK_SIZE`) until all text fits. Fragments with their own
        #   `:size` are scaled by the same ratio.
        getter overflow : Symbol

        OVERFLOW_MODES = [:truncate, :expand, :shrink_to_fit]

        # Smallest font size used by `:shrink_to_fit`.
        MIN_SHRINK_SIZE = 5.0

        # Font size step used by `:shrink_to_fit`.
        SHRINK_STEP = 0.5

        # Leading (extra space between lines)
        getter leading : Float64

        # Vertical metrics mode, see `FontMeasurer` (`:fixed` or `:font`)
        getter metrics : Symbol

        # The line height of the last rendered line
        getter line_height : Float64 = 0.0

        # The ascender of the last rendered line
        getter ascender : Float64 = 0.0

        # The descender of the last rendered line
        getter descender : Float64 = 0.0

        # Whether nothing was printed
        getter? nothing_printed : Bool = true

        # Whether everything was printed
        getter? everything_printed : Bool = false

        # The actual height consumed by rendered text: from the top of the
        # box to the descender of the last rendered line. Zero when nothing
        # was printed.
        getter rendered_height : Float64 = 0.0

        # The number of lines rendered by the last `#render`.
        getter line_count : Int32 = 0

        @formatted_text : Array(FragmentHash)
        @document : Document
        @font_name : String
        @font_size : Float64

        def initialize(
          *,
          formatted_text : Array(FragmentHash),
          @at : Tuple(Float64, Float64),
          @width : Float64,
          @height : Float64 = Float64::MAX,
          @align : Symbol = :left,
          @overflow : Symbol = :truncate,
          @leading : Float64 = 0.0,
          @document : Document,
          @font_name : String = "Helvetica",
          @font_size : Float64 = 12.0,
          @metrics : Symbol = :fixed,
        )
          unless OVERFLOW_MODES.includes?(@overflow)
            raise ArgumentError.new("Invalid overflow mode: #{@overflow.inspect}. Expected one of #{OVERFLOW_MODES.map(&.inspect).join(", ")}")
          end
          unless FontMeasurer::METRICS_MODES.includes?(@metrics)
            raise ArgumentError.new("Invalid metrics mode: #{@metrics.inspect}. Expected one of #{FontMeasurer::METRICS_MODES.map(&.inspect).join(", ")}")
          end
          @formatted_text = formatted_text
        end

        # The y coordinate below the last rendered line (the top of the box
        # minus `#rendered_height`). Place the next element here to continue
        # the layout below the text. Equal to the top of the box when nothing
        # was printed.
        def cursor : Float64
          @at[1] - @rendered_height
        end

        # Renders the formatted text into the given page.
        #
        # Returns an array of fragment hashes representing any text that
        # did not fit within the box dimensions.
        def render(page : Page) : Array(FragmentHash)
          result = with_overflow_strategy { layout_pass(page) }
          @line_height = result.line_height
          @ascender = result.ascender
          @descender = result.descender
          @line_count = result.line_count
          @nothing_printed = result.line_count == 0
          @everything_printed = result.remaining.empty?
          @rendered_height = result.height
          result.remaining
        end

        # Performs a dry run to calculate dimensions without drawing.
        # Returns the height that the text would use and the remaining text
        # that would not fit.
        def dry_run : Tuple(Float64, Array(FragmentHash))
          result = with_overflow_strategy { layout_pass(nil) }
          {result.height, result.remaining}
        end

        # The height limit in effect for the current overflow mode.
        private def height_limit : Float64
          @overflow == :expand ? Float64::MAX : @height
        end

        # Runs the block at the original size, or for `:shrink_to_fit` at the
        # largest size (stepping down by `SHRINK_STEP`) at which all text fits.
        private def with_overflow_strategy(&)
          return yield unless @overflow == :shrink_to_fit

          original_size = @font_size
          original_text = @formatted_text
          size = original_size
          begin
            loop do
              @font_size = size
              @formatted_text = scale_fragments(original_text, size / original_size)
              break if layout_pass(nil).remaining.empty?
              break if size - SHRINK_STEP < MIN_SHRINK_SIZE
              size -= SHRINK_STEP
            end
            yield
          ensure
            @font_size = original_size
            @formatted_text = original_text
          end
        end

        private def scale_fragments(fragments : Array(FragmentHash), ratio : Float64) : Array(FragmentHash)
          fragments.map do |hash|
            copy = hash.dup
            if (frag_size = copy[:size]?).is_a?(Float64)
              copy[:size] = frag_size * ratio
            end
            copy
          end
        end

        # The outcome of one layout pass.
        private record PassResult,
          remaining : Array(FragmentHash),
          height : Float64,
          line_count : Int32,
          line_height : Float64,
          ascender : Float64,
          descender : Float64

        # Wraps the text into lines that fit the box. With a page, each line
        # that fits is drawn; without one, the pass only measures. The
        # metrics of a line that does not fit are not kept, so the height
        # ends at the descender of the last line that fits.
        private def layout_pass(page : Page?) : PassResult
          font_measurer = FontMeasurer.new(@document, @font_name, @font_size, @metrics)
          arranger = Arranger.new
          line_wrap = LineWrap.new
          arranger.format_array = @formatted_text

          baseline_y = 0.0
          line_count = 0
          line_height = ascender = descender = 0.0

          loop do
            line_wrap.wrap_line(arranger: arranger, width: @width, font_measurer: font_measurer)

            # No progress possible (nothing consumed, no newline): stop
            if arranger.consumed.empty? && !line_wrap.newline_encountered? && !arranger.finished?
              arranger.repack_unretrieved
              break
            end

            next_line_height = arranger.max_line_height
            next_baseline = if line_count == 0
                              -arranger.max_ascender
                            else
                              baseline_y - (next_line_height + @leading)
                            end

            if next_baseline.abs + arranger.max_descender > height_limit + 0.0001
              # No room for this line
              arranger.repack_unretrieved
              break
            end

            baseline_y = next_baseline
            line_height = next_line_height
            ascender = arranger.max_ascender
            descender = arranger.max_descender
            line_count += 1

            draw_line(page, arranger, line_wrap, font_measurer, baseline_y) if page

            break if arranger.finished?
          end

          height = line_count == 0 ? 0.0 : baseline_y.abs + descender
          PassResult.new(arranger.unconsumed, height, line_count, line_height, ascender, descender)
        end

        private def draw_line(page : Page, arranger : Arranger, line_wrap : LineWrap,
                              font_measurer : FontMeasurer, baseline_y : Float64) : Nil
          fragments = arranger.fragments.dup
          return if fragments.empty?

          trim_trailing_whitespace(fragments, font_measurer)
          line_width = fragments.sum(&.actual_width)

          # Calculate word spacing for justified text
          word_spacing = 0.0
          if @align == :justify && !line_wrap.paragraph_finished?(arranger)
            total_spaces = fragments.sum(&.space_count)
            if total_spaces > 0
              word_spacing = (@width - line_width) / total_spaces
            end
          end

          # Calculate starting x position based on alignment
          x_offset = case @align
                     when :center
                       (@width - line_width) / 2.0
                     when :right
                       @width - line_width
                     else # :left, :justify
                       0.0
                     end

          accumulated_x = 0.0

          fragments.each do |fragment|
            fragment.word_spacing = word_spacing

            # Calculate x position
            x = @at[0] + x_offset + accumulated_x
            y = @at[1] + baseline_y + fragment.y_offset

            fragment.left = x
            fragment.baseline = @at[1] + baseline_y

            # Draw the fragment
            draw_fragment(page, fragment, x, y, font_measurer)

            accumulated_x += fragment.actual_width
          end
        end

        # Trailing whitespace is not visible, so it must not count towards
        # the line width, alignment, or justified word spacing.
        private def trim_trailing_whitespace(fragments : Array(Fragment), font_measurer : FontMeasurer) : Nil
          fragments.reverse_each do |fragment|
            trimmed = fragment.text.rstrip
            if trimmed.size != fragment.text.size
              fragment.text = trimmed
              fragment.width = font_measurer.measure_width(trimmed, fragment.format_state)
            end
            break unless trimmed.empty?
          end
        end

        private def draw_fragment(page : Page, fragment : Fragment, x : Float64, y : Float64, font_measurer : FontMeasurer) : Nil
          return if fragment.text.empty? || fragment.text == "\n"

          # Resolve the font for this fragment
          font = font_measurer.font(fragment.format_state)
          font_size = font_measurer.effective_size(fragment.format_state)

          # Save graphics state for color changes
          rgb = fragment.color.try { |color| parse_hex_color(color) }

          if rgb
            page.save_graphics_state
            page.fill_color(*rgb)
          end

          # Set font and draw text
          page.font(font, size: font_size)

          if fragment.word_spacing != 0.0
            # For justified text, draw word by word with extra spacing
            draw_justified_fragment(page, fragment, x, y, font, font_size)
          else
            page.text(fragment.text, at: {x, y})
          end

          end_x = fragment.left + fragment.actual_width
          # Draw underline if needed
          draw_decoration_line(page, x, end_x, y - 1.25, font_size, rgb) if fragment.underline?
          # Draw strikethrough if needed
          draw_decoration_line(page, x, end_x, y + (fragment.ascender * 0.3), font_size, rgb) if fragment.strikethrough?

          page.restore_graphics_state if rgb
        end

        private def draw_decoration_line(page : Page, x : Float64, end_x : Float64, line_y : Float64,
                                         font_size : Float64, rgb : Tuple(Float64, Float64, Float64)?) : Nil
          page.save_graphics_state
          page.stroke_color(*rgb) if rgb
          page.line_width(font_size * 0.05)
          page.move_to(x, line_y)
          page.line_to(end_x, line_y)
          page.stroke
          page.restore_graphics_state
        end

        private def draw_justified_fragment(page : Page, fragment : Fragment, x : Float64, y : Float64,
                                            font : Fonts::Base, font_size : Float64) : Nil
          words = fragment.text.split(' ')
          current_x = x

          words.each_with_index do |word, i|
            page.text(word, at: {current_x, y})
            word_width = font.string_width(word, font_size)
            current_x += word_width
            if i < words.size - 1
              # Add space width + extra word spacing
              space_width = font.string_width(" ", font_size)
              current_x += space_width + fragment.word_spacing
            end
          end
        end

        private def parse_hex_color(hex : String) : Tuple(Float64, Float64, Float64)
          digits = hex.lchop('#')
          unless digits.matches?(/\A(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/)
            raise ArgumentError.new("Invalid hex color: #{hex.inspect}. Use RGB or RRGGBB, with an optional leading #.")
          end

          if digits.size == 3
            r = digits[0..0].to_i(16) / 15.0
            g = digits[1..1].to_i(16) / 15.0
            b = digits[2..2].to_i(16) / 15.0
          else
            r = digits[0..1].to_i(16) / 255.0
            g = digits[2..3].to_i(16) / 255.0
            b = digits[4..5].to_i(16) / 255.0
          end
          {r, g, b}
        end
      end
    end
  end
end
