require "../../../spec_helper"

private def td_ys(page : PDF::Page) : Array(Float64)
  page.content_string.scan(/(-?[\d.]+) (-?[\d.]+) Td/).map(&.[2].to_f)
end

private def lines(count : Int32) : String
  (1..count).map { |i| "line#{i}" }.join("\n")
end

describe "PDF::Page#formatted_text_flow" do
  it "continues the text in the next box" do
    doc = PDF::Document.new
    doc.page do |page|
      # Each box holds 3 lines at 12pt: 12 + 2 * 14.4 = 40.8.
      result = page.formatted_text_flow(lines(5), boxes: [
        {at: {50, 700}, width: 200, height: 41},
        {at: {300, 700}, width: 200, height: 41},
      ])
      result.everything_printed?.should be_true
      result.box_index.should eq(1)
      result.line_count.should eq(5)
      result.cursor.should be_close(700 - 26.4, 1e-9)
      content = page.content_string
      content.should match(/50 [\d.]+ Td\n\(line3\)/)
      content.should match(/300 [\d.]+ Td\n\(line4\)/)
    end
  end

  it "returns the text that does not fit in any box" do
    doc = PDF::Document.new
    doc.page do |page|
      result = page.formatted_text_flow(lines(4), boxes: [{at: {50, 700}, width: 200, height: 13}])
      result.line_count.should eq(1)
      result.remaining.map(&.[:text]).join.should eq("line2\nline3\nline4")
    end
  end

  it "skips a box that cannot hold a line" do
    doc = PDF::Document.new
    doc.page do |page|
      result = page.formatted_text_flow("text", boxes: [
        {at: {50, 700}, width: 200, height: 5},
        {at: {50, 600}, width: 200, height: 50},
      ])
      result.box_index.should eq(1)
      result.everything_printed?.should be_true
    end
  end

  it "raises without boxes" do
    doc = PDF::Document.new
    doc.page do |page|
      expect_raises(ArgumentError, /at least one frame/) do
        page.formatted_text_flow("text", boxes: [] of NamedTuple(at: Tuple(Int32, Int32), width: Int32, height: Int32))
      end
    end
  end
end

describe "PDF::Document#formatted_text_flow" do
  it "adds pages until all text is printed" do
    doc = PDF::Document.new
    result = doc.formatted_text_flow(lines(7), at: {72, 720}, width: 300, height: 41)
    doc.pages.size.should eq(3)
    result.page.should be(doc.pages.last)
    result.everything_printed?.should be_true
    result.line_count.should eq(7)
    doc.pages[2].content_string.should contain("(line7)")
    doc.pages[1].content_string.should contain("(line4)")
  end

  it "yields each new page before drawing on it" do
    doc = PDF::Document.new
    headers = 0
    doc.formatted_text_flow(lines(4), at: {72, 720}, width: 300, height: 41) do |page|
      page.content_string.should be_empty
      page.font("Helvetica", size: 8)
      page.text("header", at: {72, 760})
      headers += 1
    end
    headers.should eq(2)
  end

  it "starts on an existing page at the cursor" do
    doc = PDF::Document.new
    first = doc.page { }
    first.formatted_text_box("intro", at: {72, 720}, width: 300) do |intro|
      result = doc.formatted_text_flow(lines(3), at: {72, 720}, width: 300, height: 41,
        start_page: first, cursor: intro.cursor)
      # The first box has 41 - 12 = 29pt left: two lines, then a new page.
      doc.pages.size.should eq(2)
      first.content_string.should contain("(line2)")
      result.page.content_string.should contain("(line3)")
      td_ys(first)[1].should be_close(720 - 12 - 9.6, 1e-9)
    end
  end

  it "uses the page size for new pages" do
    doc = PDF::Document.new
    result = doc.formatted_text_flow("x", at: {36, 400}, width: 300, height: 300, page_width: 420, page_height: 595)
    {result.page.width, result.page.height}.should eq({420.0, 595.0})
  end

  it "stops when a new page cannot hold one line" do
    doc = PDF::Document.new
    result = doc.formatted_text_flow("too big", at: {72, 720}, width: 300, height: 5)
    doc.pages.size.should eq(1)
    result.nothing_printed?.should be_true
    result.remaining.map(&.[:text]).join.should eq("too big")
  end

  it "flows a markup string with styles across pages" do
    doc = PDF::Document.new
    doc.formatted_text_flow("<b>one</b>\n<i>two</i>", at: {72, 720}, width: 300, height: 13)
    doc.pages.size.should eq(2)
    doc.pages[1].content_string.should contain("(two)")
  end
end
