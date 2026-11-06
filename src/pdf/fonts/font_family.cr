module PDF
  module Fonts
    # The style variants (normal, bold, italic, bold italic) of one
    # typeface, registered under a family name with
    # `Document#font_family`.
    #
    # A missing variant falls back to the closest registered one: bold
    # italic uses bold, then italic, then normal. Bold and italic use normal.
    #
    # ```
    # family = PDF::Fonts::FontFamily.new("Sans", normal: regular, bold: bold)
    # family.variant(bold: true, italic: false) # => bold
    # family.variant(bold: true, italic: true)  # => bold (no bold italic)
    # ```
    class FontFamily
      getter name : String
      getter normal : Base
      getter bold : Base?
      getter italic : Base?
      getter bold_italic : Base?

      def initialize(@name : String, *, @normal : Base, @bold : Base? = nil,
                     @italic : Base? = nil, @bold_italic : Base? = nil)
      end

      # Returns the font for the given style, with the fallbacks above.
      def variant(*, bold : Bool, italic : Bool) : Base
        if bold && italic
          @bold_italic || @bold || @italic || @normal
        elsif bold
          @bold || @normal
        elsif italic
          @italic || @normal
        else
          @normal
        end
      end
    end
  end
end
