module PDF
  module Fonts
    # Abstract base class for font handlers.
    abstract class Base
      # Returns the font name as it appears in the PDF.
      abstract def name : String

      # Returns the PDF font dictionary for this font.
      abstract def to_dictionary : Objects::Dictionary

      # Returns the width of a glyph in 1/1000 of the font's em-square.
      abstract def glyph_width(char : Char) : Int32

      # Returns the ascender (height above the baseline) in 1/1000 of the
      # font's em-square. The default reproduces the fixed ratio used by
      # `Text::Formatted::FontMeasurer::ASCENDER_RATIO`. Subclasses return
      # the real value from the font data.
      def ascender : Int32
        800
      end

      # Returns the descender (depth below the baseline) in 1/1000 of the
      # font's em-square. The value is negative or zero.
      def descender : Int32
        -200
      end

      # Returns the extra space between lines in 1/1000 of the font's
      # em-square.
      def line_gap : Int32
        200
      end

      # Returns the distance between two baselines in points at the given
      # size: `(ascender - descender + line_gap) * size / 1000`.
      def line_height(size : Float64) : Float64
        (ascender - descender + line_gap) * size / 1000.0
      end

      # Returns the width of a string in points at the given size.
      def string_width(text : String, size : Float64) : Float64
        total = text.each_char.sum { |char| glyph_width(char) }
        total * size / 1000.0
      end
    end
  end
end
