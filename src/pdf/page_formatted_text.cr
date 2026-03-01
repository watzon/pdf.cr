module PDF
  class Page
    # Draws formatted text within a bounded box on the page.
    #
    # Formatted text is an array of hashes, each describing a fragment
    # of text with its formatting. Supported keys:
    # - `:text` (String) - the text content
    # - `:styles` (Array(Symbol)) - :bold, :italic, :underline, :strikethrough, :subscript, :superscript
    # - `:color` (String?) - hex color string (e.g., "FF0000")
    # - `:font` (String?) - font name override
    # - `:size` (Float64?) - font size override
    #
    # ```
    # page.formatted_text_box(
    #   [
    #     {text: "Hello ", styles: [] of Symbol},
    #     {text: "world", styles: [:bold]},
    #     {text: "!", styles: [:italic], color: "FF0000"},
    #   ],
    #   at: {50, 700},
    #   width: 400,
    #   height: 200,
    #   align: :justify,
    #   overflow: :truncate,
    # )
    # ```
    #
    # Returns any text that did not fit within the box.
    def formatted_text_box(
      fragments : Array(Text::Formatted::FragmentHash),
      *,
      at : Tuple(Number, Number),
      width : Number,
      height : Number = Float64::MAX,
      align : Symbol = :left,
      overflow : Symbol = :truncate,
      leading : Number = 0,
      font_name : String = "Helvetica",
      font_size : Number = 12
    ) : Array(Text::Formatted::FragmentHash)
      box = Text::Formatted::Box.new(
        formatted_text: fragments,
        at: {at[0].to_f, at[1].to_f},
        width: width.to_f,
        height: height.to_f,
        align: align,
        overflow: overflow,
        leading: leading.to_f,
        document: @document,
        font_name: font_name,
        font_size: font_size.to_f,
      )
      box.render(self)
    end
  end
end
