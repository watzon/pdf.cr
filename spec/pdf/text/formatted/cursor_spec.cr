require "../../../spec_helper"

private def td_ys(page : PDF::Page) : Array(Float64)
  page.content_string.scan(/(-?[\d.]+) (-?[\d.]+) Td/).map(&.[2].to_f)
end

private def frag(text : String, size : Float64? = nil) : PDF::Text::Formatted::FragmentHash
  hash = PDF::Text::Formatted::FragmentHash.new
  hash[:text] = text
  hash[:styles] = [] of Symbol
  hash[:size] = size if size
  hash
end

describe "formatted text cursor tracking" do
  it "yields the end position of the text from Page#formatted_text_box" do
    doc = PDF::Document.new
    doc.page do |page|
      yielded = nil
      remaining = page.formatted_text_box("one\ntwo", at: {50, 700}, width: 400) do |result|
        yielded = result
      end
      result = yielded.should_not be_nil
      remaining.should be_empty
      result.everything_printed?.should be_true
      result.line_count.should eq(2)
      result.page.should be(page)
      # Fixed metrics at 12pt: first line ascender + descender (12), then one line pitch (14.4).
      result.rendered_height.should be_close(26.4, 1e-9)
      result.cursor.should be_close(700 - 26.4, 1e-9)
    end
  end

  it "continues the layout below the previous text at the cursor" do
    doc = PDF::Document.new
    doc.page do |page|
      page.formatted_text_box("first", at: {50, 700}, width: 400) do |result|
        page.formatted_text_box("second", at: {50, result.cursor}, width: 400)
      end
      first, second = td_ys(page)
      # The second baseline sits one ascender (9.6) below the first descender (2.4).
      (first - second).should be_close(12.0, 1e-9)
    end
  end

  it "also yields the result for named tuple fragments" do
    doc = PDF::Document.new
    doc.page do |page|
      remaining = page.formatted_text_box([{text: "a b c d e f", styles: [] of Symbol}], at: {50, 700}, width: 400, height: 5) do |result|
        result.nothing_printed?.should be_true
        result.cursor.should eq(700.0)
      end
      remaining.map(&.[:text]).join.should eq("a b c d e f")
    end
  end

  it "reports zero height and the box top when nothing fits" do
    doc = PDF::Document.new
    doc.page do |page|
      box = PDF::Text::Formatted::Box.new(formatted_text: [frag("hello")], at: {50.0, 700.0},
        width: 400.0, height: 5.0, document: doc)
      box.render(page).should_not be_empty
      box.nothing_printed?.should be_true
      box.rendered_height.should eq(0.0)
      box.cursor.should eq(700.0)
    end
  end

  it "ends the height at the last line that fits, not at the line that was cut" do
    doc = PDF::Document.new
    doc.page do |page|
      # The second line (40pt) does not fit. Its descender must not count.
      box = PDF::Text::Formatted::Box.new(formatted_text: [frag("small\n"), frag("big", 40.0)],
        at: {50.0, 700.0}, width: 400.0, height: 20.0, document: doc)
      box.render(page).map(&.[:text]).should eq(["big"])
      box.line_count.should eq(1)
      box.rendered_height.should be_close(12.0, 1e-9)
      box.descender.should be_close(2.4, 1e-9)
      box.dry_run[0].should be_close(12.0, 1e-9)
    end
  end
end

describe "formatted text box boundaries" do
  it "keeps the line break when the line after it does not fit" do
    doc = PDF::Document.new
    doc.page do |page|
      remaining = page.formatted_text_box("aaa\nbbb\nccc", at: {50, 700}, width: 400, height: 15)
      remaining.map(&.[:text]).join.should eq("bbb\nccc")
    end
  end

  it "keeps a blank line that does not fit" do
    doc = PDF::Document.new
    doc.page do |page|
      remaining = page.formatted_text_box("aaa\n\nccc", at: {50, 700}, width: 400, height: 15)
      remaining.map(&.[:text]).join.should eq("\nccc")
    end
  end
end

describe "formatted text with real font metrics" do
  it "places the first baseline one font ascender below the top" do
    doc = PDF::Document.new
    doc.page do |page|
      page.formatted_text_box("hi", at: {50, 500}, width: 400, font_size: 10, metrics: :font)
      td_ys(page).first.should be_close(500 - 7.18, 1e-9) # Helvetica ascender 718
    end
  end

  it "spaces lines by ascender - descender + line gap" do
    doc = PDF::Document.new
    doc.page do |page|
      page.formatted_text_box("a\nb", at: {50, 500}, width: 400, font_size: 10, metrics: :font) do |result|
        first, second = td_ys(page)
        (first - second).should be_close(11.56, 1e-9) # (718 + 207 + 231) / 100
        result.rendered_height.should be_close(7.18 + 11.56 + 2.07, 1e-9)
      end
    end
  end

  it "uses the metrics of each line's tallest font" do
    doc = PDF::Document.new
    doc.page do |page|
      page.formatted_text_box([{text: "x", font: "Courier", styles: [] of Symbol}],
        at: {50, 500}, width: 400, font_size: 10, metrics: :font)
      td_ys(page).first.should be_close(500 - 6.29, 1e-9) # Courier ascender 629
    end
  end

  it "keeps the fixed ratios by default" do
    doc = PDF::Document.new
    doc.page do |page|
      page.formatted_text_box("hi", at: {50, 500}, width: 400, font_size: 10)
      td_ys(page).first.should be_close(500 - 10 * PDF::Text::Formatted::FontMeasurer::ASCENDER_RATIO, 1e-9)
    end
  end

  it "rejects an unknown metrics mode" do
    doc = PDF::Document.new
    expect_raises(ArgumentError, /metrics mode/) do
      PDF::Text::Formatted::Box.new(formatted_text: [frag("x")], at: {0.0, 0.0}, width: 10.0,
        document: doc, metrics: :exact)
    end
  end
end
