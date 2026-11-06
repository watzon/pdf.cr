module PDF
  module Text
    module Formatted
      # Provides text measurement capabilities for the formatted text engine.
      # This bridges the gap between the text layout engine and the underlying
      # font system in pdf.cr.
      #
      # It resolves the correct font based on the fragment's format state
      # (bold, italic, etc.) and delegates width measurement to the font's
      # `string_width` method. Font names can be standard 14 base names or
      # families registered with `Document#font_family`.
      #
      # Vertical metrics depend on the metrics mode:
      # - `:fixed` (default) uses `LINE_HEIGHT_MULTIPLIER`, `ASCENDER_RATIO`
      #   and `DESCENDER_RATIO` for every font.
      # - `:font` uses the ascender, descender and line gap of the font
      #   (`Fonts::Base#ascender`, `#descender`, `#line_gap`).
      class FontMeasurer
        # Default font size when none is specified
        DEFAULT_FONT_SIZE = 12.0

        # Default line height multiplier (relative to font size)
        LINE_HEIGHT_MULTIPLIER = 1.2

        # Default ascender ratio (relative to font size)
        ASCENDER_RATIO = 0.8

        # Default descender ratio (relative to font size)
        DESCENDER_RATIO = 0.2

        # Supported vertical metrics modes.
        METRICS_MODES = [:fixed, :font]

        # The document that owns the fonts
        @document : Document

        # The base font size
        @font_size : Float64

        # The base font name
        @font_name : String

        # The vertical metrics mode (:fixed or :font)
        getter metrics_mode : Symbol

        def initialize(@document : Document, @font_name : String = "Helvetica",
                       @font_size : Float64 = DEFAULT_FONT_SIZE, @metrics_mode : Symbol = :fixed)
          unless METRICS_MODES.includes?(@metrics_mode)
            raise ArgumentError.new("Invalid metrics mode: #{@metrics_mode.inspect}. Expected one of #{METRICS_MODES.map(&.inspect).join(", ")}")
          end
        end

        # Returns font metrics for the given format state.
        def metrics(format_state : FormatState) : NamedTuple(line_height: Float64, ascender: Float64, descender: Float64)
          size = effective_size(format_state)
          if @metrics_mode == :font
            font = font(format_state)
            {
              line_height: font.line_height(size),
              ascender:    font.ascender * size / 1000.0,
              descender:   -font.descender * size / 1000.0,
            }
          else
            {
              line_height: size * LINE_HEIGHT_MULTIPLIER,
              ascender:    size * ASCENDER_RATIO,
              descender:   size * DESCENDER_RATIO,
            }
          end
        end

        # Measures the width of a string given the format state.
        def measure_width(text : String, format_state : FormatState) : Float64
          return 0.0 if text.empty?

          font(format_state).string_width(text, effective_size(format_state))
        end

        # Returns the font for the format state: the fragment font (or the
        # base font) in the bold and italic style of the fragment.
        def font(format_state : FormatState) : Fonts::Base
          @document.font(
            format_state.font || @font_name,
            bold: format_state.styles.includes?(:bold),
            italic: format_state.styles.includes?(:italic),
          )
        end

        # Returns the effective font size, considering the format state
        # and subscript/superscript scaling.
        def effective_size(format_state : FormatState) : Float64
          size = format_state.size || @font_size
          if format_state.styles.includes?(:subscript) || format_state.styles.includes?(:superscript)
            size * 0.583
          else
            size
          end
        end

        # Bold/italic variants of the standard 14 PDF fonts, indexed by
        # `(bold ? 1 : 0) + (italic ? 2 : 0)`.
        STYLE_VARIANTS = {
          "Helvetica"   => {"Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique"},
          "Times-Roman" => {"Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic"},
          "Times"       => {"Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic"},
          "Courier"     => {"Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique"},
        }

        # Resolves a font name with style variants.
        # Maps base font names to their bold/italic/bold-italic variants
        # for the standard 14 PDF fonts. Already-qualified or unknown font
        # names are returned as-is.
        def self.resolve_font_name(base_name : String, styles : Array(Symbol)) : String
          variants = STYLE_VARIANTS[base_name]?
          return base_name unless variants

          index = (styles.includes?(:bold) ? 1 : 0) + (styles.includes?(:italic) ? 2 : 0)
          variants[index]
        end
      end
    end
  end
end
