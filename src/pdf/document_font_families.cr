module PDF
  class Document
    # Registered font families (family name -> variants)
    @font_families = {} of String => Fonts::FontFamily

    # Font families registered with `#font_family`.
    getter font_families : Hash(String, Fonts::FontFamily)

    # Registers a font family, so that formatted text can use bold and italic
    # variants of a TrueType font.
    #
    # Each variant is a `Fonts::Base`, the name of a standard 14 font, or the
    # path of a TrueType font file. A missing variant falls back as described
    # in `Fonts::FontFamily`. Registering a name again replaces the family.
    #
    # ```
    # pdf.font_family("DejaVu",
    #   normal: "fonts/DejaVuSans.ttf",
    #   bold: "fonts/DejaVuSans-Bold.ttf",
    #   italic: "fonts/DejaVuSans-Oblique.ttf",
    #   bold_italic: "fonts/DejaVuSans-BoldOblique.ttf")
    #
    # pdf.page do |page|
    #   page.formatted_text_box("Plain <b>bold</b> <i>italic</i>",
    #     at: {72, 720}, width: 400, font_name: "DejaVu")
    # end
    # ```
    def font_family(
      name : String,
      *,
      normal : String | Fonts::Base,
      bold : (String | Fonts::Base)? = nil,
      italic : (String | Fonts::Base)? = nil,
      bold_italic : (String | Fonts::Base)? = nil,
    ) : Fonts::FontFamily
      @font_families[name] = Fonts::FontFamily.new(
        name,
        normal: family_font(normal),
        bold: bold.try { |font| family_font(font) },
        italic: italic.try { |font| family_font(font) },
        bold_italic: bold_italic.try { |font| family_font(font) },
      )
    end

    # Returns the font for a family or font name in the given style.
    #
    # A registered family returns its matching variant. A standard 14 base
    # name (`Helvetica`, `Times-Roman`, `Times`, `Courier`) returns its bold
    # or italic variant. Any other name is looked up with `#font(name)`
    # unchanged.
    def font(name : String, *, bold : Bool, italic : Bool) : Fonts::Base
      if family = @font_families[name]?
        return family.variant(bold: bold, italic: italic)
      end

      styles = [] of Symbol
      styles << :bold if bold
      styles << :italic if italic
      font(Text::Formatted::FontMeasurer.resolve_font_name(name, styles))
    end

    private def family_font(font : Fonts::Base) : Fonts::Base
      font
    end

    private def family_font(source : String) : Fonts::Base
      if Fonts::Type1::STANDARD_FONTS.includes?(source)
        font(source)
      else
        load_font(source)
      end
    end
  end
end
