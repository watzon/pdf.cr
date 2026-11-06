require "../../../spec_helper"

private DEJAVU = "#{__DIR__}/../../../fixtures/fonts/DejaVuSans.ttf"

describe "formatted text with TrueType font families" do
  it "draws bold and italic fragments with the registered variants" do
    doc = PDF::Document.new
    regular = PDF::Fonts::TrueTypeFont.load(DEJAVU)
    bold = PDF::Fonts::TrueTypeFont.load(DEJAVU)
    doc.font_family("DejaVu", normal: regular, bold: bold)
    doc.page do |page|
      page.formatted_text_box("plain <b>bold</b> <i>italic</i>", at: {50, 700}, width: 400, font_name: "DejaVu")
      # Two distinct TrueType resources: italic falls back to the normal variant.
      page.content_string.scan(/\/(F\d+) [\d.]+ Tf/).map(&.[1]).uniq!.size.should eq(2)
      page.content_string.should_not contain("(plain")
    end
    regular.subset_data.size.should be > 0
    bold.subset_data.size.should be > 0
  end

  it "selects a family per fragment with the font key" do
    doc = PDF::Document.new
    doc.font_family("DejaVu", normal: DEJAVU)
    doc.page do |page|
      page.formatted_text_box([
        {text: "helvetica ", styles: [] of Symbol},
        {text: "dejavu", styles: [:bold], font: "DejaVu"},
      ], at: {50, 700}, width: 400).should be_empty
      page.content_string.should contain("(helvetica")
      page.content_string.should contain("> Tj") # hex string from the TrueType font
    end
    bytes = doc.to_slice
    String.new(bytes).should contain("/Type0")
  end

  it "measures wrapping with the TrueType widths" do
    doc = PDF::Document.new
    font = doc.load_font(DEJAVU)
    doc.font_family("DejaVu", normal: font)
    text = "wrap these words"
    width = font.string_width("wrap these", 12.0) + 0.5
    doc.page do |page|
      page.formatted_text_box(text, at: {50, 700}, width: width, font_name: "DejaVu") do |result|
        result.line_count.should eq(2)
      end
    end
  end

  it "uses the TrueType metrics with metrics: :font" do
    doc = PDF::Document.new
    doc.font_family("DejaVu", normal: DEJAVU)
    doc.page do |page|
      page.formatted_text_box("x", at: {50, 500}, width: 400, font_name: "DejaVu", font_size: 10, metrics: :font)
      page.content_string.should match(/50 490\.72 Td/) # DejaVu ascender 928
    end
  end
end
