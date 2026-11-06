require "../../spec_helper"

def layout_frag(text : String)
  h = PDF::Text::Formatted::FragmentHash.new
  h[:text] = text
  h[:styles] = [] of Symbol
  [h]
end

def layout_long_frag
  layout_frag(("word " * 400).strip)
end

def layout_td_ys(page) : Array(Float64)
  page.content_string.scan(/(-?[\d.]+) (-?[\d.]+) Td/).map(&.[2].to_f)
end

describe PDF::Page do
  describe "#bounding_box" do
    it "creates a bounding box and draws text within it" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        box = page.bounding_box(at: {50, 700}, width: 400, height: 300) do |ctx|
          ctx.text("Hello from bounding box")
          ctx.cursor.should be < 300.0
        end
        box.width.should eq(400.0)
        box.height.should eq(300.0)
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "creates a stretchy bounding box" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        box = page.bounding_box(at: {50, 700}, width: 400) do |ctx|
          ctx.text("Line 1")
          ctx.text("Line 2")
          ctx.text("Line 3")
        end
        box.stretchy?.should be_true
        box.height.should be > 0.0
      end
    end

    it "constrains content to the box dimensions" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        box = page.bounding_box(at: {50, 700}, width: 200, height: 100) do |ctx|
          ctx.width.should eq(200.0)
          ctx.height.should eq(100.0)
        end
        box.width.should eq(200.0)
      end
    end

    it "supports stroke_bounds for debugging" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        page.bounding_box(at: {50, 700}, width: 400, height: 300) do |ctx|
          ctx.stroke_bounds
        end
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "supports move_down" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        page.bounding_box(at: {50, 700}, width: 400, height: 300) do |ctx|
          initial_cursor = ctx.cursor
          ctx.move_down(50)
          ctx.cursor.should eq(initial_cursor - 50)
        end
      end
    end

    it "supports formatted_text within bounding box" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        hash1 = PDF::Text::Formatted::FragmentHash.new
        hash1[:text] = "Hello "
        hash1[:styles] = [] of Symbol
        hash2 = PDF::Text::Formatted::FragmentHash.new
        hash2[:text] = "world"
        hash2[:styles] = [:bold] of Symbol

        page.bounding_box(at: {50, 700}, width: 400, height: 300) do |ctx|
          remaining = ctx.formatted_text([hash1, hash2])
          remaining.should be_empty
        end
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end
  end

  describe "#column_box" do
    it "creates a column box with default 2 columns" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        box = page.column_box(at: {50, 700}, width: 500, height: 600) do |ctx|
          ctx.columns.should eq(2)
          ctx.current_column.should eq(0)
          ctx.text("Column 1 text")
        end
        box.columns.should eq(2)
      end
    end

    it "creates a column box with custom columns" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        box = page.column_box(at: {50, 700}, width: 500, height: 600, columns: 3, spacer: 15) do |ctx|
          ctx.columns.should eq(3)
          ctx.text("Three column layout")
        end
        box.columns.should eq(3)
        box.spacer.should eq(15.0)
      end
    end

    it "draws text within the column box" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        page.column_box(at: {50, 700}, width: 500, height: 600) do |ctx|
          ctx.text("Hello from column box")
        end
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "supports stroke_bounds for columns" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        page.column_box(at: {50, 700}, width: 500, height: 600) do |ctx|
          ctx.stroke_bounds
        end
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end
  end

  describe "regressions" do
    it "draws formatted_text in a stretchy box after plain text" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        box = page.bounding_box(at: {50, 500}, width: 200) do |b|
          b.text("stretchy")
          b.formatted_text(layout_frag("second")).should be_empty
        end
        page.content_string.should contain("second")
        box.height.should be > 14.4
      end
    end

    it "accepts named tuple fragments in bounding and column boxes" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 700}, width: 200, height: 100) do |box|
          box.formatted_text([{text: "boxed", styles: [:bold]}]).should be_empty
        end
        page.column_box(at: {50, 500}, width: 400, height: 100) do |col|
          col.formatted_text([{text: "columned", styles: [] of Symbol}]).should be_empty
        end
        page.content_string.should contain("(boxed)")
        page.content_string.should contain("(columned)")
      end
    end

    it "places the first baseline below the top of the box" do
      doc = PDF::Document.new
      doc.page do |page|
        page.bounding_box(at: {50, 500}, width: 200, height: 100) do |b|
          b.text("hi", font_size: 10)
        end
        layout_td_ys(page).first.should eq(500.0 - 10 * PDF::Text::Formatted::FontMeasurer::ASCENDER_RATIO)
      end
    end

    it "places the first baseline below the top of the column" do
      doc = PDF::Document.new
      doc.page do |page|
        page.column_box(at: {50, 500}, width: 400, height: 100) do |col|
          col.text("hi", font_size: 10)
        end
        layout_td_ys(page).first.should eq(500.0 - 10 * PDF::Text::Formatted::FontMeasurer::ASCENDER_RATIO)
      end
    end

    it "does not overprint column 0 when the last column is full" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        page.column_box(at: {50, 500}, width: 400, height: 50, columns: 2) do |col|
          rest = col.formatted_text(layout_long_frag)
          rest.should_not be_empty
          col.box.full?.should be_true
          col.current_column.should eq(1)
          before = page.content_string.size
          col.formatted_text(rest).should eq(rest)
          page.content_string.size.should eq(before)
        end
      end
    end

    it "advances plain text to the next column when the line does not fit" do
      doc = PDF::Document.new
      doc.page do |page|
        page.column_box(at: {50, 500}, width: 400, height: 40, columns: 2) do |col|
          3.times { col.text("line", font_size: 12) } # third line needs 14.4, only 11.2 left
          col.current_column.should eq(1)
          4.times { col.text("more", font_size: 12) }
        end
        ys = layout_td_ys(page)
        ys.each(&.should(be >= 460.0))
        ys.size.should eq(4) # 2 lines per column, the rest is not drawn
      end
    end
  end
end
