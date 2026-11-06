module PDF
  module Text
    module Formatted
      # Provides text measurement capabilities for the formatted text engine.
      # This bridges the gap between the text layout engine and the underlying
      # font system in pdf.cr.
      #
      # It resolves the correct font based on the fragment's format state
      # (bold, italic, etc.) and delegates width measurement to the font's
      # `string_width` method.
      class FontMeasurer
        # Default font size when none is specified
        DEFAULT_FONT_SIZE = 12.0

        # Default line height multiplier (relative to font size)
        LINE_HEIGHT_MULTIPLIER = 1.2

        # Default ascender ratio (relative to font size)
        ASCENDER_RATIO = 0.8

        # Default descender ratio (relative to font size)
        DESCENDER_RATIO = 0.2

        # The document that owns the fonts
        @document : Document

        # The base font size
        @font_size : Float64

        # The base font name
        @font_name : String

        def initialize(@document : Document, @font_name : String = "Helvetica", @font_size : Float64 = DEFAULT_FONT_SIZE)
        end

        # Returns font metrics for the given format state.
        def metrics(format_state : FormatState) : NamedTuple(line_height: Float64, ascender: Float64, descender: Float64)
          size = effective_size(format_state)
          {
            line_height: size * LINE_HEIGHT_MULTIPLIER,
            ascender:    size * ASCENDER_RATIO,
            descender:   size * DESCENDER_RATIO,
          }
        end

        # Measures the width of a string given the format state.
        def measure_width(text : String, format_state : FormatState) : Float64
          return 0.0 if text.empty?

          font = resolve_font(format_state)
          size = effective_size(format_state)
          font.string_width(text, size)
        end

        # Resolves the font name based on the format state's styles.
        private def resolve_font(format_state : FormatState) : Fonts::Base
          font_name = format_state.font || @font_name
          resolved_name = FontMeasurer.resolve_font_name(font_name, format_state.styles)
          @document.font(resolved_name)
        end

        # Returns the effective font size, considering the format state
        # and subscript/superscript scaling.
        private def effective_size(format_state : FormatState) : Float64
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
