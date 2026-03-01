require "../../spec_helper"

describe PDF::Table do
  describe "#initialize" do
    it "creates a simple table" do
      table = PDF::Table.new(
        data: [
          ["A", "B", "C"],
          ["D", "E", "F"],
        ],
      )
      table.row_count.should eq(2)
      table.column_count.should eq(3)
      table.cells.size.should eq(2)
    end

    it "creates a table with explicit column widths" do
      table = PDF::Table.new(
        data: [["A", "B"]],
        column_widths: [100.0, 200.0],
      )
      table.column_widths.should eq([100.0, 200.0])
    end

    it "creates a table with header" do
      table = PDF::Table.new(
        data: [
          ["Header 1", "Header 2"],
          ["Cell 1", "Cell 2"],
        ],
        header: true,
      )
      table.header.should eq(1)
    end

    it "creates a table with multiple header rows" do
      table = PDF::Table.new(
        data: [
          ["H1", "H2"],
          ["Sub1", "Sub2"],
          ["A", "B"],
        ],
        header: 2,
      )
      table.header.should eq(2)
    end

    it "auto-calculates column widths" do
      table = PDF::Table.new(
        data: [
          ["Short", "A much longer text here"],
          ["X", "Y"],
        ],
      )
      table.column_widths.size.should eq(2)
      # Longer column should be wider
      table.column_widths[1].should be >= table.column_widths[0]
    end

    it "calculates row heights" do
      table = PDF::Table.new(
        data: [
          ["A", "B"],
          ["C", "D"],
        ],
      )
      table.row_heights.size.should eq(2)
      table.row_heights.each { |h| h.should be > 0 }
    end
  end

  describe "#total_height" do
    it "returns the sum of all row heights" do
      table = PDF::Table.new(
        data: [
          ["A", "B"],
          ["C", "D"],
        ],
      )
      table.total_height.should eq(table.row_heights.sum)
    end
  end

  describe "#total_width" do
    it "returns the sum of all column widths" do
      table = PDF::Table.new(
        data: [["A", "B"]],
        column_widths: [100.0, 200.0],
      )
      table.total_width.should eq(300.0)
    end
  end

  describe "colspan support" do
    it "handles cells with colspan" do
      hash_cell = Hash(Symbol, String | Int32 | Float64 | Bool | Nil).new
      hash_cell[:content] = "Wide"
      hash_cell[:colspan] = 2

      row1 = ["A".as(PDF::Table::CellData), "B".as(PDF::Table::CellData), "C".as(PDF::Table::CellData)]
      row2 = [hash_cell.as(PDF::Table::CellData), "D".as(PDF::Table::CellData)]
      data = [row1, row2]

      table = PDF::Table.new(data: data)
      table.row_count.should eq(2)
      # Second row should have the spanned cell + dummy + D
      table.cells[1].size.should eq(3)
    end
  end

  describe "#draw" do
    it "draws a simple table on a page" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        table = PDF::Table.new(
          data: [
            ["Header 1", "Header 2"],
            ["Cell 1", "Cell 2"],
            ["Cell 3", "Cell 4"],
          ],
          column_widths: [150.0, 200.0],
          header: true,
        )
        final_y = table.draw(page, x: 50.0, y: 700.0)
        final_y.should be < 700.0
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "draws a table with background colors" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        table = PDF::Table.new(
          data: [
            ["A", "B"],
            ["C", "D"],
          ],
          column_widths: [100.0, 100.0],
          cell_style: ({:background_color => "EEEEEE"} of Symbol => String | Float64 | Bool | Nil),
        )
        table.draw(page, x: 50.0, y: 700.0)
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "draws a table with cell alignment" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        data = [
          ["Left".as(PDF::Table::CellData), "Center".as(PDF::Table::CellData), "Right".as(PDF::Table::CellData)],
        ]
        table = PDF::Table.new(
          data: data,
          column_widths: [150.0, 150.0, 150.0],
        )
        # Manually set alignment
        table.cells[0][1].align = :center
        table.cells[0][2].align = :right
        table.draw(page, x: 50.0, y: 700.0)
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end
  end

  describe "Page#table" do
    it "provides a convenience method on Page" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        table = page.table(
          [
            ["Header 1", "Header 2"],
            ["Cell 1", "Cell 2"],
          ],
          at: {50, 700},
          column_widths: [150.0, 200.0],
          header: true,
        )
        table.row_count.should eq(2)
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "draws a table with row colors" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        page.table(
          [
            ["A", "B"],
            ["C", "D"],
            ["E", "F"],
          ],
          at: {50, 700},
          column_widths: [100.0, 100.0],
          row_colors: ["FFFFFF", "EEEEEE"],
        )
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end
  end
end
