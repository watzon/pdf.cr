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

        # Overflow behavior (:truncate, :expand)
        getter overflow : Symbol

        # Leading (extra space between lines)
        getter leading : Float64

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

        # The actual height consumed by rendered text
        getter rendered_height : Float64 = 0.0

        @formatted_text : Array(FragmentHash)
        @document : Document
        @font_name : String
        @font_size : Float64
        @baseline_y : Float64 = 0.0

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
          @font_size : Float64 = 12.0
        )
          @formatted_text = formatted_text
        end

        # Renders the formatted text into the given page.
        #
        # Returns an array of fragment hashes representing any text that
        # did not fit within the box dimensions.
        def render(page : Page) : Array(FragmentHash)
          font_measurer = FontMeasurer.new(@document, @font_name, @font_size)
          arranger = Arranger.new
          line_wrap = LineWrap.new

          arranger.format_array = @formatted_text

          @baseline_y = 0.0
          @nothing_printed = true
          @everything_printed = false
          printed_lines = [] of String

          loop do
            # Wrap the next line
            line_text = line_wrap.wrap_line(
              arranger: arranger,
              width: @width,
              font_measurer: font_measurer,
            )

            # Check if there's enough height for this line
            @line_height = arranger.max_line_height
            @descender = arranger.max_descender
            @ascender = arranger.max_ascender

            diff = if @baseline_y == 0.0
                     @ascender + @descender
                   else
                     @descender + @line_height + @leading
                   end

            required_height = @baseline_y.abs + diff

            if required_height > @height + 0.0001
              # No room for this line
              arranger.repack_unretrieved
              break
            end

            # Move baseline down
            if @baseline_y == 0.0
              @baseline_y = -@ascender
            else
              @baseline_y -= (@line_height + @leading)
            end

            # Draw the fragments for this line
            draw_line(page, arranger, line_wrap, font_measurer)

            @nothing_printed = false
            printed_lines << line_text

            break if arranger.finished?
          end

          @everything_printed = arranger.finished?
          @rendered_height = @baseline_y.abs + @descender

          arranger.unconsumed
        end

        # Performs a dry run to calculate dimensions without drawing.
        # Returns the remaining text that would not fit.
        def dry_run : Tuple(Float64, Array(FragmentHash))
          font_measurer = FontMeasurer.new(@document, @font_name, @font_size)
          arranger = Arranger.new
          line_wrap = LineWrap.new

          arranger.format_array = @formatted_text

          baseline_y = 0.0
          line_height = 0.0
          descender_val = 0.0
          ascender_val = 0.0

          loop do
            line_wrap.wrap_line(
              arranger: arranger,
              width: @width,
              font_measurer: font_measurer,
            )

            line_height = arranger.max_line_height
            descender_val = arranger.max_descender
            ascender_val = arranger.max_ascender

            diff = if baseline_y == 0.0
                     ascender_val + descender_val
                   else
                     descender_val + line_height + @leading
                   end

            required_height = baseline_y.abs + diff

            if required_height > @height + 0.0001
              arranger.repack_unretrieved
              break
            end

            if baseline_y == 0.0
              baseline_y = -ascender_val
            else
              baseline_y -= (line_height + @leading)
            end

            break if arranger.finished?
          end

          height_used = baseline_y.abs + descender_val
          {height_used, arranger.unconsumed}
        end

        private def draw_line(page : Page, arranger : Arranger, line_wrap : LineWrap, font_measurer : FontMeasurer) : Nil
          fragments = arranger.fragments.dup
          return if fragments.empty?

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
            y = @at[1] + @baseline_y + fragment.y_offset

            fragment.left = x
            fragment.baseline = @at[1] + @baseline_y

            # Draw the fragment
            draw_fragment(page, fragment, x, y, font_measurer)

            accumulated_x += fragment.actual_width
          end
        end

        private def draw_fragment(page : Page, fragment : Fragment, x : Float64, y : Float64, font_measurer : FontMeasurer) : Nil
          return if fragment.text.empty? || fragment.text == "\n"

          # Resolve the font for this fragment
          font_name = resolve_font_name(fragment.format_state)
          font_size = fragment.size || @font_size

          if fragment.subscript? || fragment.superscript?
            font_size *= 0.583
          end

          # Save graphics state for color changes
          has_color = !fragment.color.nil?

          if has_color
            page.save_graphics_state
            color_str = fragment.color.not_nil!
            r, g, b = parse_hex_color(color_str)
            page.fill_color(r, g, b)
          end

          # Set font and draw text
          page.font(font_name, size: font_size)

          if fragment.word_spacing != 0.0
            # For justified text, draw word by word with extra spacing
            draw_justified_fragment(page, fragment, x, y, font_size)
          else
            page.text(fragment.text, at: {x, y})
          end

          # Draw underline if needed
          if fragment.underline?
            underline_y = y - 1.25
            page.save_graphics_state
            if has_color
              r, g, b = parse_hex_color(fragment.color.not_nil!)
              page.stroke_color(r, g, b)
            end
            page.line_width(font_size * 0.05)
            page.move_to(x, underline_y)
            page.line_to(fragment.left + fragment.actual_width, underline_y)
            page.stroke
            page.restore_graphics_state
          end

          # Draw strikethrough if needed
          if fragment.strikethrough?
            strike_y = y + (fragment.ascender * 0.3)
            page.save_graphics_state
            if has_color
              r, g, b = parse_hex_color(fragment.color.not_nil!)
              page.stroke_color(r, g, b)
            end
            page.line_width(font_size * 0.05)
            page.move_to(x, strike_y)
            page.line_to(fragment.left + fragment.actual_width, strike_y)
            page.stroke
            page.restore_graphics_state
          end

          if has_color
            page.restore_graphics_state
          end
        end

        private def draw_justified_fragment(page : Page, fragment : Fragment, x : Float64, y : Float64, font_size : Float64) : Nil
          words = fragment.text.split(' ')
          current_x = x
          font = @document.font(resolve_font_name(fragment.format_state))

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
          hex = hex.lstrip('#')
          if hex.size == 3
            r = hex[0..0].to_i(16) / 15.0
            g = hex[1..1].to_i(16) / 15.0
            b = hex[2..2].to_i(16) / 15.0
          elsif hex.size == 6
            r = hex[0..1].to_i(16) / 255.0
            g = hex[2..3].to_i(16) / 255.0
            b = hex[4..5].to_i(16) / 255.0
          else
            r = 0.0
            g = 0.0
            b = 0.0
          end
          {r, g, b}
        end

        private def resolve_font_name(format_state : FormatState) : String
          base = format_state.font || @font_name
          styles = format_state.styles
          has_bold = styles.includes?(:bold)
          has_italic = styles.includes?(:italic)

          case base
          when "Helvetica"
            if has_bold && has_italic
              "Helvetica-BoldOblique"
            elsif has_bold
              "Helvetica-Bold"
            elsif has_italic
              "Helvetica-Oblique"
            else
              "Helvetica"
            end
          when "Times-Roman", "Times"
            if has_bold && has_italic
              "Times-BoldItalic"
            elsif has_bold
              "Times-Bold"
            elsif has_italic
              "Times-Italic"
            else
              "Times-Roman"
            end
          when "Courier"
            if has_bold && has_italic
              "Courier-BoldOblique"
            elsif has_bold
              "Courier-Bold"
            elsif has_italic
              "Courier-Oblique"
            else
              "Courier"
            end
          else
            base
          end
        end
      end
    end
  end
end
