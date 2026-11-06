require "../src/pdf"

# Demonstrates the formatted text engine: inline markup, cursor tracking,
# flow across columns and pages, TrueType font families, and real font
# metrics.
#
# Run with: crystal run examples/formatted_text.cr
#
# To use your own TrueType family, pass the regular, bold, italic and bold
# italic files (the last three are optional):
#
#   crystal run examples/formatted_text.cr -- Regular.ttf Bold.ttf Italic.ttf BoldItalic.ttf

PARAGRAPH = "The <b>formatted text</b> engine wraps <i>styled</i> text in boxes. " \
            "A fragment can be <u>underlined</u>, <strikethrough>struck</strikethrough>, " \
            "<color rgb=\"C0392B\">colored</color>, set in <font name=\"Courier\">Courier</font>, " \
            "or moved up like x<sup>2</sup> and down like H<sub>2</sub>O. "

regular, bold, italic, bold_italic = ARGV[0]?, ARGV[1]?, ARGV[2]?, ARGV[3]?
regular ||= "#{__DIR__}/../spec/fixtures/fonts/DejaVuSans.ttf"

pdf = PDF::Document.new
pdf.font_family("Body", normal: regular, bold: bold, italic: italic, bold_italic: bold_italic)

first = pdf.page do |page|
  page.font("Helvetica-Bold", size: 18)
  page.text("Formatted text", at: {72, 740})

  # Markup and cursor tracking: each box starts below the previous one.
  page.formatted_text_box(PARAGRAPH, at: {72, 720}, width: 468, align: :justify) do |result|
    page.formatted_text_box(
      "This paragraph starts at the <b>cursor</b> of the paragraph above, 8pt lower.",
      at: {72, result.cursor - 8}, width: 468,
    ) do |second|
      # Real font metrics: the TrueType family with its own line spacing.
      page.formatted_text_box(
        "TrueType family with metrics: :font. <b>Bold</b> and <i>italic</i> use the registered " \
        "variants, or fall back to the regular font.",
        at: {72, second.cursor - 8}, width: 468, font_name: "Body", metrics: :font,
      )
    end
  end

  # Flow through two linked columns on the same page.
  page.formatted_text_flow(PARAGRAPH * 6, boxes: [
    {at: {72, 580}, width: 220, height: 200},
    {at: {320, 580}, width: 220, height: 200},
  ], align: :justify)
end

# Flow a long text from the end of the first page onto new pages, with a
# header on each new page.
page_number = 1
result = pdf.formatted_text_flow(PARAGRAPH * 40, at: {72, 720}, width: 468, height: 648,
  start_page: first, cursor: 360, align: :justify) do |page|
  page_number += 1
  page.font("Helvetica", size: 9)
  page.text("Formatted text, page #{page_number}", at: {72, 760})
end

result.page.formatted_text_box("<i>End of the flow.</i>", at: {72, result.cursor - 12}, width: 468)

pdf.save("examples/formatted_text.pdf")
puts "Saved examples/formatted_text.pdf (#{pdf.pages.size} pages)"
