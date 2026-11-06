module PDF
  class Page
    # Sets the current font to any `Fonts::Base`: a TrueType font or a
    # standard 14 font. Used by the formatted text engine, which resolves
    # fonts from font families.
    def font(font : Fonts::Base, size : Number = 12) : self
      case font
      when Fonts::TrueTypeFont
        font(font, size: size)
      else
        font(font.name, size: size)
      end
    end

    # Draws formatted text within a bounded box on the page.
    #
    # Formatted text is an array of hashes, each describing a fragment
    # of text with its formatting. Supported keys:
    # - `:text` (String) - the text content
    # - `:styles` (Array(Symbol)) - :bold, :italic, :underline, :strikethrough, :subscript, :superscript
    # - `:color` (String?) - hex color string (e.g., "FF0000")
    # - `:font` (String?) - font name override: a standard 14 font, or a
    #   family registered with `Document#font_family`
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
    # `metrics: :font` uses the ascender, descender and line gap of each
    # font for line placement. The default `:fixed` uses fixed ratios of the
    # font size (see `Text::Formatted::FontMeasurer`).
    #
    # Returns any text that did not fit within the box. To also get where
    # the text ended, use the block form.
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
      font_size : Number = 12,
      metrics : Symbol = :fixed,
    ) : Array(Text::Formatted::FragmentHash)
      render_formatted_text_box(
        fragments,
        at: at, width: width, height: height, align: align, overflow: overflow,
        leading: leading, font_name: font_name, font_size: font_size, metrics: metrics,
      ).remaining
    end

    # Overload that accepts an array of named tuples, as in the example above.
    # Each named tuple is converted to a `Text::Formatted::FragmentHash`.
    # Integer `:size` values are converted to `Float64`.
    def formatted_text_box(
      fragments : Array,
      *,
      at : Tuple(Number, Number),
      width : Number,
      height : Number = Float64::MAX,
      align : Symbol = :left,
      overflow : Symbol = :truncate,
      leading : Number = 0,
      font_name : String = "Helvetica",
      font_size : Number = 12,
      metrics : Symbol = :fixed,
    ) : Array(Text::Formatted::FragmentHash)
      hashes = Text::Formatted.to_fragment_hashes(fragments)
      formatted_text_box(
        hashes,
        at: at, width: width, height: height, align: align, overflow: overflow,
        leading: leading, font_name: font_name, font_size: font_size, metrics: metrics,
      )
    end

    # Overload that accepts a string with inline markup, parsed by
    # `Text::Formatted::Parser` (`<b>`, `<i>`, `<u>`, `<color rgb="...">`,
    # `<font name="..." size="...">` and more).
    #
    # ```
    # page.formatted_text_box("Hello <b>world</b><color rgb=\"FF0000\">!</color>",
    #   at: {50, 700}, width: 400)
    # ```
    def formatted_text_box(markup : String, **options) : Array(Text::Formatted::FragmentHash)
      formatted_text_box(Text::Formatted::Parser.format(markup), **options)
    end

    # Block form: draws the text like the forms above, then yields a
    # `Text::Formatted::Result` with the end position of the text
    # (`#cursor`), the height used and the remaining fragments. Returns the
    # remaining fragments.
    #
    # ```
    # page.formatted_text_box("A <b>first</b> paragraph.", at: {50, 700}, width: 400) do |result|
    #   page.formatted_text_box("The next paragraph.", at: {50, result.cursor - 6}, width: 400)
    # end
    # ```
    def formatted_text_box(
      fragments : Array | String,
      *,
      at : Tuple(Number, Number),
      width : Number,
      height : Number = Float64::MAX,
      align : Symbol = :left,
      overflow : Symbol = :truncate,
      leading : Number = 0,
      font_name : String = "Helvetica",
      font_size : Number = 12,
      metrics : Symbol = :fixed,
      & : Text::Formatted::Result -> _
    ) : Array(Text::Formatted::FragmentHash)
      result = render_formatted_text_box(
        Text::Formatted.coerce(fragments),
        at: at, width: width, height: height, align: align, overflow: overflow,
        leading: leading, font_name: font_name, font_size: font_size, metrics: metrics,
      )
      yield result
      result.remaining
    end

    # Flows formatted text through several boxes on this page, in order.
    # Text that does not fit in one box continues in the next box. Each box
    # is a named tuple with `at`, `width` and `height`. The fragments can be
    # fragment hashes, named tuples or a markup string.
    #
    # ```
    # result = page.formatted_text_flow(long_text,
    #   boxes: [
    #     {at: {50, 700}, width: 250, height: 300},
    #     {at: {310, 700}, width: 250, height: 300},
    #   ],
    #   align: :justify)
    # result.remaining # => text that did not fit in either box
    # ```
    def formatted_text_flow(
      fragments : Array | String,
      *,
      boxes : Array,
      align : Symbol = :left,
      leading : Number = 0,
      font_name : String = "Helvetica",
      font_size : Number = 12,
      metrics : Symbol = :fixed,
    ) : Text::Formatted::Result
      frames = boxes.map do |box|
        corner = box[:at]
        Text::Formatted::Flow::Frame.new(self, {corner[0].to_f, corner[1].to_f}, box[:width].to_f, box[:height].to_f)
      end
      flow = Text::Formatted::Flow.new(@document, align: align, leading: leading.to_f,
        font_name: font_name, font_size: font_size.to_f, metrics: metrics)
      flow.render(Text::Formatted.coerce(fragments)) { |index| frames[index]? }
    end

    private def render_formatted_text_box(
      fragments : Array(Text::Formatted::FragmentHash),
      *,
      at : Tuple(Number, Number),
      width : Number,
      height : Number,
      align : Symbol,
      overflow : Symbol,
      leading : Number,
      font_name : String,
      font_size : Number,
      metrics : Symbol,
    ) : Text::Formatted::Result
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
        metrics: metrics,
      )
      remaining = box.render(self)
      Text::Formatted::Result.new(
        remaining: remaining, page: self, cursor: box.cursor,
        rendered_height: box.rendered_height, box_index: 0, line_count: box.line_count,
      )
    end
  end
end
