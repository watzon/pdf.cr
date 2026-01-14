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

      # Returns the width of a string in points at the given size.
      def string_width(text : String, size : Float64) : Float64
        total = text.each_char.sum { |c| glyph_width(c) }
        total * size / 1000.0
      end
    end
  end
end
