require "../../../spec_helper"

private def wrap_lines(markup : String, width : Float64) : Array(String)
  doc = PDF::Document.new
  measurer = PDF::Text::Formatted::FontMeasurer.new(doc)
  arranger = PDF::Text::Formatted::Arranger.new
  line_wrap = PDF::Text::Formatted::LineWrap.new
  arranger.format_array = PDF::Text::Formatted::Parser.format(markup)
  lines = [] of String
  until arranger.finished?
    lines << line_wrap.wrap_line(arranger: arranger, width: width, font_measurer: measurer)
  end
  lines
end

private def helvetica_width(text : String) : Float64
  PDF::Fonts::Type1.new("Helvetica").string_width(text, 12.0)
end

describe "line wrapping at style boundaries" do
  it "does not break a word where its style changes" do
    lines = wrap_lines("aaaa bbbb H<sub>2</sub>O", helvetica_width("aaaa bbbb H") + 0.5)
    lines.should eq(["aaaa bbbb ", "H2O"])
  end

  it "moves a word made of several styled parts to the next line" do
    lines = wrap_lines("aaaa <b>bb</b><i>cc</i><u>dd</u>", helvetica_width("aaaa bbcc") + 0.5)
    lines.should eq(["aaaa ", "bbccdd"])
  end

  it "still breaks at a style change that follows a space" do
    lines = wrap_lines("aaaa bbbb <b>cccc</b>", helvetica_width("aaaa bbbb ") + 0.5)
    lines.should eq(["aaaa bbbb ", "cccc"])
  end

  it "still breaks after a hyphen before a style change" do
    lines = wrap_lines("aaaa well-<b>known</b>", helvetica_width("aaaa well-") + 0.5)
    lines.should eq(["aaaa well-", "known"])
  end

  it "breaks at the style change when the word alone is wider than the line" do
    lines = wrap_lines("<b>aaaa</b>bbbb", helvetica_width("aaaa") + 0.5)
    lines.first.should eq("aaaa")
  end

  it "keeps the styles of the moved word" do
    doc = PDF::Document.new
    doc.page do |page|
      page.formatted_text_box("aaaa bbbb x<sup>2</sup>", at: {50, 700}, width: helvetica_width("aaaa bbbb x") + 0.5) do |result|
        result.line_count.should eq(2)
      end
      content = page.content_string
      content.should match(/\(x\) Tj/)
      content.should match(/\/F\d+ 6\.996 Tf\n[^\n]*\n\(2\) Tj/) # superscript size 12 * 0.583
    end
  end

  it "puts back the original fragments when a line with a moved word does not fit" do
    doc = PDF::Document.new
    doc.page do |page|
      # Line 2 moves "bbcc" to line 3, then line 2 does not fit in the box.
      remaining = page.formatted_text_box("aaaa\nx y <b>bb</b><i>cc</i> z",
        at: {50, 700}, width: helvetica_width("x y bbc") + 0.5, height: 14)
      remaining.map { |hash| {hash[:text], hash[:styles]} }.should eq([
        {"x y ", [] of Symbol},
        {"bb", [:bold]},
        {"cc", [:italic]},
        {" z", [] of Symbol},
      ])
    end
  end
end
