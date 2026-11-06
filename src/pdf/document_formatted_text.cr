module PDF
  class Document
    # Flows formatted text from page to page. The text fills a box with the
    # same position and size on each page, and new pages are added until all
    # text is printed. The fragments can be fragment hashes, named tuples or
    # a markup string.
    #
    # To continue on an existing page, pass `start_page`, and optionally
    # `cursor` (the y coordinate where the text starts on that page, for
    # example the `cursor` of an earlier `Text::Formatted::Result`). The
    # first box then runs from `cursor` down to the bottom of the box.
    #
    # Returns a `Text::Formatted::Result` with the last page and the cursor
    # on it. When a new page cannot hold one line (the box is too small for
    # the font), the flow stops and the result holds the remaining text.
    #
    # ```
    # result = pdf.formatted_text_flow(chapter, at: {72, 720}, width: 468, height: 648)
    # result.page   # => the last page
    # result.cursor # => where the next element can start on that page
    # ```
    def formatted_text_flow(
      fragments : Array | String,
      *,
      at : Tuple(Number, Number),
      width : Number,
      height : Number,
      page_width : Number = 612,
      page_height : Number = 792,
      start_page : Page? = nil,
      cursor : Number? = nil,
      align : Symbol = :left,
      leading : Number = 0,
      font_name : String = "Helvetica",
      font_size : Number = 12,
      metrics : Symbol = :fixed,
    ) : Text::Formatted::Result
      formatted_text_flow(
        fragments,
        at: at, width: width, height: height, page_width: page_width, page_height: page_height,
        start_page: start_page, cursor: cursor, align: align, leading: leading,
        font_name: font_name, font_size: font_size, metrics: metrics,
      ) { }
    end

    # Block form: yields each new page before text is drawn on it, for
    # example to draw a header or a page number.
    #
    # ```
    # pdf.formatted_text_flow(chapter, at: {72, 720}, width: 468, height: 648) do |page|
    #   page.font("Helvetica", size: 9)
    #   page.text("Chapter 1", at: {72, 750})
    # end
    # ```
    def formatted_text_flow(
      fragments : Array | String,
      *,
      at : Tuple(Number, Number),
      width : Number,
      height : Number,
      page_width : Number = 612,
      page_height : Number = 792,
      start_page : Page? = nil,
      cursor : Number? = nil,
      align : Symbol = :left,
      leading : Number = 0,
      font_name : String = "Helvetica",
      font_size : Number = 12,
      metrics : Symbol = :fixed,
      & : Page ->
    ) : Text::Formatted::Result
      x = at[0].to_f
      top = at[1].to_f
      box_width = width.to_f
      box_height = height.to_f
      previous_on_new_page = false

      flow = Text::Formatted::Flow.new(self, align: align, leading: leading.to_f,
        font_name: font_name, font_size: font_size.to_f, metrics: metrics)
      flow.render(Text::Formatted.coerce(fragments)) do |index, previous|
        if index == 0 && start_page
          y = cursor.try(&.to_f) || top
          Text::Formatted::Flow::Frame.new(start_page, {x, y}, box_width, Math.max(0.0, box_height - (top - y)))
        else
          # A new page that printed nothing means the box cannot hold a line.
          next if previous_on_new_page && previous.try(&.nothing_printed?)

          new_page = page(page_width, page_height) { |created| yield created }
          previous_on_new_page = true
          Text::Formatted::Flow::Frame.new(new_page, {x, top}, box_width, box_height)
        end
      end
    end
  end
end
