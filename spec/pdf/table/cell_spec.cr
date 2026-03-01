require "../../spec_helper"

describe PDF::Table::Cell do
  describe "#initialize" do
    it "creates a cell with default values" do
      cell = PDF::Table::Cell.new("Hello")
      cell.content.should eq("Hello")
      cell.row.should eq(0)
      cell.column.should eq(0)
      cell.colspan.should eq(1)
      cell.rowspan.should eq(1)
      cell.font_name.should eq("Helvetica")
      cell.font_size.should eq(10.0)
      cell.align.should eq(:left)
      cell.bold.should be_false
      cell.italic.should be_false
      cell.span_dummy?.should be_false
    end

    it "has default padding" do
      cell = PDF::Table::Cell.new("Test")
      cell.padding.should eq([5.0, 5.0, 5.0, 5.0])
      cell.padding_top.should eq(5.0)
      cell.padding_right.should eq(5.0)
      cell.padding_bottom.should eq(5.0)
      cell.padding_left.should eq(5.0)
    end

    it "has default borders" do
      cell = PDF::Table::Cell.new("Test")
      cell.borders.should eq([:top, :bottom, :left, :right])
      cell.border_width.should eq(1.0)
      cell.border_color.should eq("000000")
    end
  end

  describe ".make" do
    it "creates a cell from a string" do
      cell = PDF::Table::Cell.make("Hello")
      cell.content.should eq("Hello")
    end

    it "creates a cell from a hash with content" do
      data = Hash(Symbol, String | Int32 | Float64 | Bool | Nil).new
      data[:content] = "Hello"
      data[:colspan] = 2
      cell = PDF::Table::Cell.make(data)
      cell.content.should eq("Hello")
      cell.colspan.should eq(2)
    end

    it "creates a cell from a hash with background_color" do
      data = Hash(Symbol, String | Int32 | Float64 | Bool | Nil).new
      data[:content] = "Hello"
      data[:background_color] = "CCCCCC"
      cell = PDF::Table::Cell.make(data)
      cell.background_color.should eq("CCCCCC")
    end

    it "passes through an existing cell" do
      original = PDF::Table::Cell.new("Original")
      cell = PDF::Table::Cell.make(original)
      cell.should be(original)
    end
  end

  describe "#natural_height" do
    it "calculates height for single line" do
      cell = PDF::Table::Cell.new("Hello")
      cell.font_size = 12.0
      height = cell.natural_height
      # 1 line * 12 * 1.2 + 5 + 5 = 24.4
      height.should be_close(24.4, 0.1)
    end

    it "calculates height for multi-line content" do
      cell = PDF::Table::Cell.new("Line 1\nLine 2\nLine 3")
      cell.font_size = 12.0
      height = cell.natural_height
      # 3 lines * 12 * 1.2 + 5 + 5 = 53.2
      height.should be_close(53.2, 0.1)
    end
  end

  describe "#create_span_dummy" do
    it "creates a span dummy cell" do
      master = PDF::Table::Cell.new("Master")
      master.row = 0
      master.column = 0

      dummy = master.create_span_dummy(1, 0)
      dummy.span_dummy?.should be_true
      dummy.master_cell.should eq(master)
      dummy.row.should eq(1)
      dummy.column.should eq(0)
      dummy.borders.should be_empty
      dummy.content.should eq("")
    end
  end

  describe "#content_width and #content_height" do
    it "calculates content dimensions" do
      cell = PDF::Table::Cell.new("Test")
      cell.width = 100.0
      cell.height = 50.0
      cell.content_width.should eq(90.0) # 100 - 5 - 5
      cell.content_height.should eq(40.0) # 50 - 5 - 5
    end
  end
end
