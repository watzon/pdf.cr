require "../../spec_helper"

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
end
