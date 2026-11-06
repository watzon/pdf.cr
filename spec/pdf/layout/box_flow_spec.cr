require "../../spec_helper"

# Regression specs for issue #2: nested boxes, indent, spans, column page
# breaks and plain-text overflow in bounding boxes.

ASCENT = PDF::Text::Formatted::FontMeasurer::ASCENDER_RATIO

def flow_frag(text : String)
  h = PDF::Text::Formatted::FragmentHash.new
  h[:text] = text
  h[:styles] = [] of Symbol
  [h]
end

# All {x, y} text positions in the content stream of a page.
def flow_tds(page : PDF::Page) : Array(Tuple(Float64, Float64))
  page.content_string.scan(/(-?[\d.]+) (-?[\d.]+) Td/).map { |match| {match[1].to_f, match[2].to_f} }
end

def flow_count(page : PDF::Page, operator : String) : Int32
  page.content_string.lines.count(&.==(operator))
end

describe "PDF::Page box flow" do
  describe "nested bounding boxes" do
    it "places a nested box at the parent cursor and links the parent" do
      doc = PDF::Document.new
      doc.page do |page|
        outer = page.bounding_box(at: {50, 700}, width: 400, height: 300) do |box|
          box.move_down(20)
          inner = box.bounding_box(width: 100, height: 50) do |child|
            child.cursor.should eq(50.0)
            child.width.should eq(100.0)
          end
          inner.parent.should be(box.box)
          inner.absolute_left.should eq(50.0)
          inner.absolute_top.should eq(680.0)
          # The parent cursor moves below the nested box.
          box.cursor.should eq(230.0)
        end
        outer.height.should eq(300.0)
      end
    end

    it "measures an explicit at from the left and bottom of the parent" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 700}, width: 400, height: 300) do |box|
          inner = box.bounding_box(at: {10, 100}, height: 40) do |child|
            child.text("nested", font_size: 10).should be_true
          end
          inner.absolute_top_left.should eq({60.0, 500.0})
          inner.width.should eq(390.0)
        end
        flow_tds(page).should eq([{60.0, 500.0 - 10 * ASCENT}])
      end
    end

    it "uses local coordinates at each nesting level" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 700}, width: 400, height: 300) do |a|
          a.bounding_box(at: {20, 280}, width: 300, height: 200) do |b|
            b.bounding_box(at: {30, 150}, width: 100, height: 50) do |third|
              third.box.absolute_top_left.should eq({100.0, 630.0})
              third.text("deep", font_size: 10)
            end
          end
        end
        flow_tds(page).should eq([{100.0, 630.0 - 10 * ASCENT}])
      end
    end

    it "stretches a stretchy parent to contain the nested box" do
      doc = PDF::Document.new
      doc.page do |page|
        outer = page.bounding_box(at: {50, 700}, width: 400) do |box|
          box.text("top")
          box.bounding_box(width: 100, height: 60) { }
        end
        outer.height.should be_close(14.4 + 60.0, 1e-9)
      end
    end

    it "stops a stretchy nested box at the bottom of a fixed parent" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 700}, width: 400, height: 30) do |box|
          box.bounding_box do |child|
            child.text("one").should be_true
            child.text("two").should be_true
            child.text("three").should be_false
          end
        end
        flow_tds(page).size.should eq(2)
      end
    end

    it "places a nested box in the current column" do
      doc = PDF::Document.new
      doc.page do |page|
        page.column_box(at: {50, 500}, width: 400, height: 40, columns: 2, spacer: 20) do |col|
          3.times { col.text("line") } # the third line moves to column 1
          inner = col.bounding_box(height: 10) { }
          inner.absolute_left.should eq(260.0)
          inner.width.should eq(190.0)
          inner.absolute_top.should be_close(500.0 - 14.4, 1e-9)
          col.cursor.should be_close(40.0 - 14.4 - 10.0, 1e-9)
        end
      end
    end
  end

  describe "indent" do
    it "indents text in a bounding box and restores the width" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 700}, width: 400, height: 300) do |box|
          box.indent(20, 10) do
            box.width.should eq(370.0)
            box.text("indented")
            box.bounding_box(height: 10) { }.absolute_left.should eq(70.0)
          end
          box.width.should eq(400.0)
          box.text("flush")
        end
        flow_tds(page).map(&.[0]).should eq([70.0, 50.0])
      end
    end

    it "indents each column of a column box" do
      doc = PDF::Document.new
      doc.page do |page|
        page.column_box(at: {50, 500}, width: 400, height: 200, columns: 2, spacer: 20) do |col|
          col.indent(10, 10) do
            col.width.should eq(170.0)
            col.formatted_text(flow_frag("indented")).should be_empty
          end
          col.width.should eq(190.0)
        end
        flow_tds(page).first[0].should eq(60.0)
      end
    end
  end

  describe "span" do
    it "spans the full width below all columns and starts a new section" do
      doc = PDF::Document.new
      doc.page do |page|
        page.column_box(at: {50, 500}, width: 400, height: 200, columns: 2, spacer: 20) do |col|
          col.text("left")
          col.box.advance_column
          col.text("right one")
          col.text("right two")
          span = col.span do |span_ctx|
            span_ctx.width.should eq(400.0)
            span_ctx.text("title")
          end
          span.absolute_left.should eq(50.0)
          span.absolute_top.should be_close(500.0 - 2 * 14.4, 1e-9)
          col.current_column.should eq(0)
          col.cursor.should be_close(200.0 - 3 * 14.4, 1e-9)
          col.text("below")
          # The next column of this section starts below the span too.
          col.box.advance_column
          col.cursor.should be_close(200.0 - 3 * 14.4, 1e-9)
        end
        tds = flow_tds(page)
        tds[3][0].should eq(50.0)
        tds[3][1].should be_close(500.0 - 2 * 14.4 - 12 * ASCENT, 1e-9)
        tds[4][0].should eq(50.0)
        tds[4][1].should be_close(500.0 - 3 * 14.4 - 12 * ASCENT, 1e-9)
      end
    end

    it "positions a narrow span" do
      doc = PDF::Document.new
      doc.page do |page|
        page.column_box(at: {50, 500}, width: 400, height: 200) do |col|
          col.span(100, position: :center) { }.absolute_left.should eq(200.0)
          col.span(100, position: :right) { }.absolute_left.should eq(350.0)
          expect_raises(ArgumentError, /span position/) { col.span(100, position: :middle) { } }
        end
      end
    end
  end

  describe "column box page breaks" do
    it "continues formatted text on new pages at the same box position" do
      doc = PDF::Document.new
      last_page = nil
      doc.page do |page|
        page.column_box(at: {50, 500}, width: 400, height: 50, columns: 2) do |col|
          col.formatted_text(flow_frag(("word " * 400).strip)).should be_empty
          last_page = col.page
        end
      end
      doc.pages.size.should be > 1
      last_page.should be(doc.pages.last)
      first = flow_tds(doc.pages[0]).first
      flow_tds(doc.pages[1]).first.should eq(first)
      doc.pages.each { |pdf_page| flow_tds(pdf_page).each(&.[1].should(be > 450.0)) }
    end

    it "continues plain text on a new page" do
      doc = PDF::Document.new
      doc.page do |page|
        page.column_box(at: {50, 500}, width: 400, height: 40, columns: 2) do |col|
          6.times { col.text("line").should be_true } # 2 lines per column
        end
      end
      doc.pages.size.should eq(2)
      flow_tds(doc.pages[0]).size.should eq(4)
      flow_tds(doc.pages[1]).should eq([{50.0, 500.0 - 12 * ASCENT}, {50.0, 500.0 - 14.4 - 12 * ASCENT}])
    end

    it "runs page break hooks on each new page" do
      doc = PDF::Document.new
      seen = [] of PDF::Page
      doc.page do |page|
        page.column_box(at: {50, 500}, width: 400, height: 40, columns: 2) do |col|
          col.on_page_break do |ctx|
            seen << ctx.page
            ctx.page.font("Helvetica", size: 8).text("continued", at: {50, 520})
          end
          10.times { col.text("line") }
        end
      end
      doc.pages.size.should eq(3)
      seen.should eq(doc.pages[1..])
      doc.pages[1].content_string.should contain("(continued)")
    end

    it "does not start pages for a line that cannot fit an empty column" do
      doc = PDF::Document.new
      doc.page do |page|
        page.column_box(at: {50, 500}, width: 400, height: 40) do |col|
          col.text("huge", font_size: 100).should be_false
          col.formatted_text(flow_frag("huge"), font_size: 100).should_not be_empty
        end
      end
      doc.pages.size.should eq(1)
    end

    it "updates the page of the enclosing contexts" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 700}, width: 400, height: 600) do |outer|
          outer.column_box(height: 40) do |col|
            6.times { col.text("line") }
          end
          outer.page.should be(doc.pages.last)
          outer.text("after").should be_true
        end
      end
      doc.pages.size.should eq(2)
      doc.pages[1].content_string.should contain("(after)")
    end

    it "repeats the clipping of an enclosing box on the new page" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 700}, width: 400, height: 600, overflow: :clip) do |outer|
          outer.column_box(height: 40) do |col|
            6.times { col.text("line") }
          end
        end
      end
      doc.pages.size.should eq(2)
      doc.pages.each do |pdf_page|
        pdf_page.content_string.should start_with("q\n50 100 400 600 re\nW\nn\n")
        flow_count(pdf_page, "q").should eq(1)
        flow_count(pdf_page, "Q").should eq(1)
      end
    end
  end

  describe "plain text overflow" do
    it "truncates lines past the bottom of a fixed box by default" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 700}, width: 400, height: 30) do |box|
          box.overflow.should eq(:truncate)
          box.text("one").should be_true
          box.text("two").should be_true
          box.text("three").should be_false
          box.cursor.should be_close(30.0 - 2 * 14.4, 1e-9)
        end
        page.content_string.should_not contain("(three)")
      end
    end

    it "draws lines outside the box with overflow: :visible" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 700}, width: 400, height: 30, overflow: :visible) do |box|
          3.times { box.text("line").should be_true }
        end
        flow_tds(page).size.should eq(3)
        page.content_string.should_not contain("W\n")
      end
    end

    it "clips content to the box with overflow: :clip" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 700}, width: 400, height: 30, overflow: :clip) do |box|
          3.times { box.text("line").should be_true }
        end
        content = page.content_string
        content.should start_with("q\n50 670 400 30 re\nW\nn\n")
        content.should end_with("Q\n")
        flow_tds(page).size.should eq(3)
      end
    end

    it "rejects clip without a fixed height and unknown modes" do
      doc = PDF::Document.new
      doc.page do |page|
        expect_raises(ArgumentError, /fixed height/) do
          page.bounding_box(at: {50, 700}, width: 400, overflow: :clip) { }
        end
        expect_raises(ArgumentError, /Unknown overflow/) do
          page.bounding_box(at: {50, 700}, width: 400, height: 30, overflow: :scroll) { }
        end
      end
    end
  end
end
