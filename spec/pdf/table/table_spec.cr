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
      table.row_heights.each(&.should(be > 0))
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
      hash_cell = Hash(Symbol, String | Int32 | Float64 | Bool?).new
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
          cell_style: ({:background_color => "EEEEEE"} of Symbol => String | Float64 | Bool?),
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

    it "applies row_colors as alternating cell backgrounds" do
      table = PDF::Table.new(
        data: [
          ["A", "B"],
          ["C", "D"],
          ["E", "F"],
        ],
        column_widths: [100.0, 100.0],
        row_colors: ["FFFFFF", "EEEEEE"],
      )

      table.cells[0].each(&.background_color.should eq("FFFFFF"))
      table.cells[1].each(&.background_color.should eq("EEEEEE"))
      table.cells[2].each(&.background_color.should eq("FFFFFF"))
    end

    it "excludes header rows from row_colors striping" do
      table = PDF::Table.new(
        data: [
          ["Header 1", "Header 2"],
          ["A", "B"],
          ["C", "D"],
        ],
        header: true,
        column_widths: [100.0, 100.0],
        row_colors: ["FFFFFF", "EEEEEE"],
      )

      table.cells[0].each(&.background_color.should be_nil)
      table.cells[1].each(&.background_color.should eq("FFFFFF"))
      table.cells[2].each(&.background_color.should eq("EEEEEE"))
    end

    it "does not override an explicit per-cell background with row_colors" do
      hash_cell = Hash(Symbol, String | Int32 | Float64 | Bool?).new
      hash_cell[:content] = "A"
      hash_cell[:background_color] = "FF0000"

      table = PDF::Table.new(
        data: [[hash_cell.as(PDF::Table::CellData), "B".as(PDF::Table::CellData)]],
        column_widths: [100.0, 100.0],
        row_colors: ["EEEEEE"],
      )

      table.cells[0][0].background_color.should eq("FF0000")
      table.cells[0][1].background_color.should eq("EEEEEE")
    end
  end

  describe "Page#table pagination" do
    it "flows overflowing rows onto new pages and repeats the header" do
      doc = PDF::Document.new
      doc.page(612, 792) do |page|
        page.font("Helvetica", size: 10)
        data = [["Header 1", "Header 2"]] + Array.new(60) { |i| ["Row #{i} A", "Row #{i} B"] }
        page.table(
          data,
          at: {50, 700},
          column_widths: [200.0, 200.0],
          header: true,
        )
      end

      doc.pages.size.should be > 1

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end
  end

  describe "regressions (PR #7 review)" do
    it "accepts the documented Page#table literal" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        # The literal from the Page#table doc comment.
        table = page.table(
          [
            ["Header 1", "Header 2", "Header 3"],
            ["Cell 1", {content: "Cell 2", colspan: 2}],
          ],
          at: {50, 700},
          header: true,
          column_widths: [100.0, 150.0, 150.0],
        )
        table.row_count.should eq(2)
        table.column_count.should eq(3)
      end
    end

    it "rejects column_widths that do not match the column count" do
      doc = PDF::Document.new
      doc.page do |page|
        expect_raises(ArgumentError, /3 columns/) do
          page.table(
            [["Header 1", "Header 2"], ["Cell 1", {content: "Cell 2", colspan: 2}]],
            at: {50, 700}, column_widths: [100.0, 200.0],
          )
        end
      end
    end

    it "accepts a plain string-array table" do
      doc = PDF::Document.new
      doc.page do |page|
        page.table([["a", "b"]], at: {50, 700}).row_count.should eq(1)
      end
    end

    it "draws bold and italic Times and Courier cells" do
      doc = PDF::Document.new
      doc.page do |page|
        %w[Helvetica Times-Roman Courier].each do |family|
          t = page.table([[{content: "x", font_name: family, bold: true, italic: true}]], at: {50, 700})
          t.cells[0][0].effective_font_name.should_not contain("Roman-")
        end
      end
      PDF::Table::Cell.new("x").tap { |cell| cell.font_name = "Times-Roman"; cell.bold = true }.effective_font_name.should eq("Times-Bold")
      PDF::Table::Cell.new("x").tap { |cell| cell.font_name = "Times-Roman"; cell.italic = true }.effective_font_name.should eq("Times-Italic")
      PDF::Table::Cell.new("x").tap { |cell| cell.font_name = "Courier"; cell.bold = true; cell.italic = true }.effective_font_name.should eq("Courier-BoldOblique")
      PDF::Table::Cell.new("x").tap(&.bold=(true)).effective_font_name.should eq("Helvetica-Bold")
      PDF::Table::Cell.new("x").tap(&.italic=(true)).effective_font_name.should eq("Helvetica-Oblique")
    end

    it "draws each line of multi-line content separately" do
      doc = PDF::Document.new
      doc.page do |page|
        page.table([["one\ntwo"]], at: {50, 700})
        s = page.content_string
        s.should contain("(one) Tj")
        s.should contain("(two) Tj")
        s.should_not contain("one\ntwo")
      end
    end

    it "right-aligns text using real font metrics" do
      doc = PDF::Document.new
      doc.page do |page|
        table = PDF::Table.new(data: [["WWWW"] of PDF::Table::CellData], column_widths: [200.0])
        table.cells[0][0].align = :right
        page.font("Helvetica", size: 10)
        table.draw(page, x: 50.0, y: 700.0)
        cell = table.cells[0][0]
        text_x = page.content_string.match!(/([\d.]+) [\d.]+ Td\n\(WWWW\)/)[1].to_f
        (text_x + cell.text_width("WWWW")).should be_close(250.0 - cell.padding_right, 0.5)
      end
    end

    it "raises when column_widths size differs from the column count" do
      expect_raises(ArgumentError, /column_widths/) do
        PDF::Table.new(data: [["a", "b", "c"] of PDF::Table::CellData], column_widths: [50.0, 50.0])
      end
    end

    it "breaks before the first row when it does not fit" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        breaks = 0
        table = PDF::Table.new(data: [["a"] of PDF::Table::CellData], column_widths: [100.0])
        table.draw_with_page_breaks(page, x: 50.0, y: 60.0, available_height: 10.0) do
          breaks += 1
          {doc.page { }, 700.0}
        end
        breaks.should eq(1)
      end
    end

    it "draws a row taller than a page without looping" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        breaks = 0
        table = PDF::Table.new(data: [["a"] of PDF::Table::CellData], column_widths: [100.0])
        table.draw_with_page_breaks(page, x: 50.0, y: 60.0, available_height: 1.0) do
          breaks += 1
          {doc.page { }, 5.0}
        end
        breaks.should eq(1)
      end
    end

    it "keeps rowspan groups on one page" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        data = [
          [({:content => "span", :rowspan => 2} of Symbol => String | Int32 | Float64 | Bool?), "b"] of PDF::Table::CellData,
          ["c"] of PDF::Table::CellData,
        ]
        table = PDF::Table.new(data: data, column_widths: [100.0, 100.0])
        h = table.row_heights
        breaks = 0
        # Room for the first row only: the group must move as a whole.
        table.draw_with_page_breaks(page, x: 50.0, y: 700.0, available_height: h[0] + 1.0) do
          breaks += 1
          {doc.page { }, 700.0}
        end
        breaks.should eq(1)
        table.cells[0][0].y.should eq(700.0)
      end
    end
  end
end
