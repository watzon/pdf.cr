require "../../spec_helper"

# Regression specs for the table scope of issue #3: percentage widths,
# per-side padding and borders, vertical alignment, header styles, text
# wrapping, image and nested-table cells, and the end position.

private alias Options = Hash(Symbol, String | Int32 | Float64 | Bool?)

private def png
  PDF::Images::Image.load("spec/fixtures/images/test_rgb.png")
end

# Baseline y of each drawn text string in a content stream.
private def text_baselines(content : String) : Hash(String, Float64)
  result = {} of String => Float64
  content.scan(/[\d.]+ ([\d.]+) Td\n\((.*?)\) Tj/) { |match| result[match[2]] = match[1].to_f }
  result
end

describe PDF::Table do
  describe "percentage column widths" do
    it "resolves percentages against table_width" do
      table = PDF::Table.new(data: [["a", "b"] of PDF::Table::CellData], column_widths: ["25%", "75%"], table_width: 400.0)
      table.column_widths.should eq([100.0, 300.0])
    end

    it "mixes points and percentages against the available page width" do
      doc = PDF::Document.new
      doc.page(612, 792) do |page|
        table = page.table([["a", "b"]], at: {50, 700}, column_widths: ["50%", 100.0])
        # 612 - 50 (x) - 50 (right margin) = 512
        table.column_widths.should eq([256.0, 100.0])
      end
    end

    it "raises without a basis for percentages" do
      expect_raises(ArgumentError, /table_width or available_width/) do
        PDF::Table.new(data: [["a"] of PDF::Table::CellData], column_widths: ["50%"])
      end
    end

    it "raises for a string that is not a percentage" do
      expect_raises(ArgumentError, /not a percentage/) do
        PDF::Table.new(data: [["a"] of PDF::Table::CellData], column_widths: ["wide"], table_width: 100.0)
      end
    end
  end

  describe "per-side padding" do
    it "expands padding lists from named tuples" do
      doc = PDF::Document.new
      doc.page do |page|
        table = page.table([[{content: "a", padding: [1, 2, 3, 4]}, {content: "b", padding: [6, 8]}]], at: {50, 700})
        table.cells[0][0].padding.should eq([1.0, 2.0, 3.0, 4.0])
        table.cells[0][1].padding.should eq([6.0, 8.0, 6.0, 8.0])
      end
    end

    it "accepts per-side keys in typed hashes and positions text with them" do
      cell = {:content => "x", :padding => 2, :padding_left => 20, :padding_top => 9} of Symbol => String | Int32 | Float64 | Bool?
      table = PDF::Table.new(data: [[cell] of PDF::Table::CellData], column_widths: [100.0])
      table.cells[0][0].padding.should eq([9.0, 2.0, 2.0, 20.0])
      table.row_heights[0].should be_close(9.0 + 12.0 + 2.0, 0.001)

      doc = PDF::Document.new
      doc.page do |page|
        table.draw(page, x: 50.0, y: 700.0)
        page.content_string.should contain("70 681 Td\n(x) Tj")
      end
    end

    it "lets cell padding win over cell_style padding" do
      doc = PDF::Document.new
      doc.page do |page|
        table = page.table([["a", {content: "b", padding_left: 12}]], at: {50, 700}, cell_style: {padding: [3, 4]})
        table.cells[0][0].padding.should eq([3.0, 4.0, 3.0, 4.0])
        table.cells[0][1].padding.should eq([3.0, 4.0, 3.0, 12.0])
      end
    end
  end

  describe "per-side borders" do
    it "draws only the selected sides with their own width and color" do
      doc = PDF::Document.new
      doc.page do |page|
        table = page.table(
          [[{content: "a", borders: [:top, :bottom], border_widths: [0.5, 1, 2, 1], border_colors: ["FF0000", "000000", "0000FF", "000000"]}]],
          at: {50, 700},
          column_widths: [100.0],
        )
        cell = table.cells[0][0]
        cell.borders.should eq([:top, :bottom])
        cell.border_width_for(:bottom).should eq(2.0)
        cell.border_color_for(:top).should eq("FF0000")

        s = page.content_string
        s.scan(/^S$/m).size.should eq(2)
        s.should contain("1 0 0 RG\n0.5 w\n50 700 m\n150 700 l\nS")
        s.should contain("0 0 1 RG\n2 w\n50 #{(700 - table.row_heights[0]).round(4).to_s.rchop(".0")} m")
      end
    end

    it "accepts border lists as strings and none" do
      none = PDF::Table::Cell.make({:content => "x", :borders => "none"} of Symbol => String | Int32 | Float64 | Bool?)
      none.borders.should be_empty
      some = PDF::Table::Cell.make({:content => "x", :borders => "left, right"} of Symbol => String | Int32 | Float64 | Bool?)
      some.borders.should eq([:left, :right])
      expect_raises(ArgumentError, /border side/) do
        PDF::Table::Cell.make({:content => "x", :borders => "middle"} of Symbol => String | Int32 | Float64 | Bool?)
      end
    end

    it "applies borders from cell_style to every cell" do
      doc = PDF::Document.new
      doc.page do |page|
        table = page.table([["a", "b"], ["c", "d"]], at: {50, 700}, cell_style: {borders: [:bottom], border_width: 0.25})
        table.cells.flatten.each do |cell|
          cell.borders.should eq([:bottom])
          cell.border_width.should eq(0.25)
        end
      end
    end
  end

  describe "vertical alignment" do
    it "places text at the top, center or bottom of a tall row" do
      doc = PDF::Document.new
      doc.page do |page|
        table = page.table(
          [["line\nline\nline\nline", {content: "top"}, {content: "mid", valign: :center}, {content: "low", valign: "bottom"}]],
          at: {50, 700},
        )
        table.cells[0][2].valign.should eq(:center)

        cell = table.cells[0][1]
        free = cell.content_height - cell.line_height
        ys = text_baselines(page.content_string)
        (ys["top"] - ys["mid"]).should be_close(free / 2.0, 0.01)
        (ys["top"] - ys["low"]).should be_close(free, 0.01)
      end
    end
  end

  describe "header_style" do
    it "styles header rows only and lets cell options win" do
      doc = PDF::Document.new
      doc.page do |page|
        table = page.table(
          [["H1", {content: "H2", background_color: "FF0000"}], ["a", "b"]],
          at: {50, 700},
          header: true,
          cell_style: {background_color: "FFFFFF"},
          header_style: {background_color: "DDDDDD", font_style: :bold, text_color: "333333"},
        )
        h1, h2 = table.cells[0]
        h1.background_color.should eq("DDDDDD")
        h1.bold?.should be_true
        h1.effective_font_name.should eq("Helvetica-Bold")
        h1.text_color.should eq("333333")
        h2.background_color.should eq("FF0000")
        table.cells[1].each do |cell|
          cell.bold?.should be_false
          cell.background_color.should eq("FFFFFF")
        end
      end
    end

    it "repeats the styled header on every page" do
      doc = PDF::Document.new
      doc.page(612, 792) do |page|
        data = [["Header 1", "Header 2"]] + Array.new(80) { |i| ["Row #{i}", "Value #{i}"] }
        page.table(data, at: {50, 700}, column_widths: [200.0, 200.0], header: true,
          header_style: {font_style: :bold, background_color: "DDDDDD"})
      end

      doc.pages.size.should be > 1
      doc.pages.each do |page|
        s = page.content_string
        s.should contain("(Header 1) Tj")
        s.should contain("0.8667 0.8667 0.8667 rg")
      end
    end

    it "rejects an unknown font_style" do
      expect_raises(ArgumentError, /font_style/) do
        PDF::Table.new(data: [["a"] of PDF::Table::CellData], header: true, header_style: {font_style: :heavy})
      end
    end
  end

  describe "text wrapping" do
    long = "The quick brown fox jumps over the lazy dog and keeps running far away"

    it "wraps long text to the content width and grows the row" do
      table = PDF::Table.new(data: [[long] of PDF::Table::CellData], column_widths: [100.0])
      cell = table.cells[0][0]
      lines = cell.wrapped_lines
      lines.size.should be > 2
      lines.join(" ").should eq(long)
      lines.each { |line| cell.text_width(line).should be <= cell.content_width }
      table.row_heights[0].should be_close(lines.size * cell.line_height + 10.0, 0.001)
    end

    it "draws each wrapped line inside the cell" do
      doc = PDF::Document.new
      doc.page do |page|
        table = page.table([[long]], at: {50, 700}, column_widths: [100.0])
        cell = table.cells[0][0]
        ys = page.content_string.scan(/([\d.]+) ([\d.]+) Td/).map(&.[2].to_f)
        ys.size.should eq(cell.wrapped_lines.size)
        ys.min.should be > 700.0 - table.row_heights[0]
      end
    end

    it "does not wrap text in an auto column sized to fit it (rounding)" do
      [8.0, 11.0].each do |size|
        cell = {:content => "Hello", :font_size => size, :padding => 7.3} of Symbol => String | Int32 | Float64 | Bool?
        table = PDF::Table.new(data: [[cell] of PDF::Table::CellData])
        table.cells[0][0].wrapped_lines.should eq(["Hello"])
      end
    end

    it "keeps the spaces of a line that fits" do
      table = PDF::Table.new(data: [["  indented  and  spaced", "a\n   b"] of PDF::Table::CellData], column_widths: [200.0, 100.0])
      table.cells[0][0].wrapped_lines.should eq(["  indented  and  spaced"])
      table.cells[0][1].wrapped_lines.should eq(["a", "   b"])
    end

    it "breaks a word that is wider than the cell" do
      table = PDF::Table.new(data: [["W" * 40] of PDF::Table::CellData], column_widths: [60.0])
      cell = table.cells[0][0]
      cell.wrapped_lines.size.should be > 1
      cell.wrapped_lines.join.should eq("W" * 40)
      cell.wrapped_lines.each { |line| cell.text_width(line).should be <= cell.content_width }
    end

    it "keeps explicit line breaks and empty lines" do
      table = PDF::Table.new(data: [["one\n\ntwo"] of PDF::Table::CellData], column_widths: [100.0])
      table.cells[0][0].wrapped_lines.should eq(["one", "", "two"])
    end

    it "shrinks auto widths to the page and wraps instead of overflowing" do
      doc = PDF::Document.new
      doc.page(612, 792) do |page|
        table = page.table([["id", long * 3]], at: {50, 700})
        table.total_width.should be_close(512.0, 0.01)
        table.column_widths[0].should be >= PDF::Table::MIN_COLUMN_WIDTH
        table.cells[0][1].wrapped_lines.size.should be > 1
      end
    end

    it "keeps auto widths that fit unchanged" do
      doc = PDF::Document.new
      doc.page do |page|
        auto = page.table([["a", "b"]], at: {50, 700}).column_widths
        auto.should eq(PDF::Table.new(data: [["a", "b"] of PDF::Table::CellData]).column_widths)
      end
    end

    it "paginates wrapped rows and keeps every row on a page" do
      doc = PDF::Document.new
      doc.page(612, 792) do |page|
        data = [["Header", "Text"]] + Array.new(30) { |i| ["#{i}", long] }
        table = page.table(data, at: {50, 700}, column_widths: [50.0, 120.0], header: true)
        table.row_heights[1].should be > table.row_heights[0]
        table.end_page.should be(doc.pages.last)
        (table.end_y || fail "end_y not set").should be >= PDF::Page::TABLE_MARGIN - 0.001
      end

      doc.pages.size.should be > 1
      doc.pages.each(&.content_string.should(contain("(Header) Tj")))
    end
  end

  describe "rowspan with wrapping" do
    it "gives a wrapped rowspan cell the height of its rows and keeps the group together" do
      doc = PDF::Document.new
      doc.page do |page|
        text = "rowspan text that needs several lines in a narrow column"
        table = page.table([[{content: text, rowspan: 2}, "b"], ["c"]], at: {50, 700}, column_widths: [60.0, 60.0])
        span = table.cells[0][0]
        span.height.should be_close(table.row_heights[0] + table.row_heights[1], 0.001)
        span.height.should be >= span.natural_height - 0.001

        breaks = 0
        table.draw_with_page_breaks(page, x: 50.0, y: 700.0, available_height: table.row_heights[0] + 1.0) do
          breaks += 1
          {doc.page { }, 700.0}
        end
        breaks.should eq(1)
        span.y.should eq(700.0)
        table.cells[1][1].y.should eq(700.0 - table.row_heights[0])
      end
    end
  end

  describe "image cells" do
    it "draws an image cell with options from a named tuple" do
      doc = PDF::Document.new
      doc.page do |page|
        table = page.table([["Logo", {image: png, image_width: 40, align: :center, valign: :bottom}]], at: {50, 700}, column_widths: [100.0, 100.0])
        cell = table.cells[0][1]
        cell.image.should_not be_nil
        cell.align.should eq(:center)
        table.row_heights[0].should be_close(40.0 + 10.0, 0.001)
        page.content_string.should contain("40 0 0 40 180 655 cm\n/Im1 Do")
      end
    end

    it "accepts a bare image and fits it into the column" do
      doc = PDF::Document.new
      doc.page do |page|
        table = page.table([[png, "text"]], at: {50, 700}, column_widths: [60.0, 100.0])
        cell = table.cells[0][0]
        cell.image_size(cell.image || fail("no image"), fit: true).should eq({50.0, 50.0})
        table.row_heights[0].should be_close(60.0, 0.001)
        page.content_string.should contain("50 0 0 50 55 645 cm")
      end
    end

    it "uses the natural image width for auto columns" do
      table = PDF::Table.new(data: [[PDF::Table::Cell.make(png, {image_height: 20})] of PDF::Table::CellData])
      table.column_widths.should eq([30.0])
      table.row_heights.should eq([30.0])
    end
  end

  describe "nested tables" do
    it "draws a nested table inside a cell and sizes the row for it" do
      doc = PDF::Document.new
      doc.page do |page|
        inner = PDF::Table.new(data: [["x", "y"] of PDF::Table::CellData, ["z", "w"] of PDF::Table::CellData], column_widths: [40.0, 40.0])
        table = page.table([["Outer", {table: inner, padding: 2}], ["after", inner]], at: {50, 700}, column_widths: [100.0, 100.0])

        table.cells[0][1].subtable.should be(inner)
        table.row_heights[0].should be_close(inner.total_height + 4.0, 0.001)
        table.row_heights[1].should be_close(inner.total_height + 10.0, 0.001)

        s = page.content_string
        s.scan(/\(x\) Tj/).size.should eq(2)
        # The second draw positions the inner table in the second row.
        inner.cells[0][0].x.should eq(155.0)
        inner.cells[0][0].y.should be_close(700.0 - table.row_heights[0] - 5.0, 0.001)
      end
    end

    it "uses the nested table width for auto columns" do
      inner = PDF::Table.new(data: [["a", "b"] of PDF::Table::CellData], column_widths: [70.0, 70.0])
      table = PDF::Table.new(data: [["label", inner] of PDF::Table::CellData])
      table.column_widths[1].should eq(150.0)
    end
  end

  describe "end position" do
    it "reports the page and y below a table that fits" do
      doc = PDF::Document.new
      doc.page do |page|
        table = page.table([["a", "b"], ["c", "d"]], at: {50, 700})
        table.end_page.should be(page)
        table.end_y.should eq(700.0 - table.total_height)
      end
    end

    it "lets content continue below a table that spans pages" do
      doc = PDF::Document.new
      doc.page(612, 792) do |page|
        data = [["H"]] + Array.new(70) { |i| ["row #{i}"] }
        table = page.table(data, at: {50, 700}, header: true)
        end_page = table.end_page || fail "end_page not set"
        end_page.should_not be(page)
        end_page.should be(doc.pages.last)

        end_y = table.end_y || fail "end_y not set"
        end_page.font("Helvetica", size: 10)
        end_page.text("Below", at: {50, end_y - 20})
        last_row = table.cells.last.first
        (last_row.y - last_row.height).should be_close(end_y, 0.001)
      end

      doc.pages.last.content_string.should contain("(Below) Tj")
    end

    it "is set by Table#draw" do
      doc = PDF::Document.new
      doc.page do |page|
        table = PDF::Table.new(data: [["a"] of PDF::Table::CellData])
        table.end_y.should be_nil
        y = table.draw(page, x: 10.0, y: 500.0)
        table.end_y.should eq(y)
        table.end_page.should be(page)
      end
    end
  end

  describe "existing row types" do
    it "still accepts typed CellData rows with hashes" do
      doc = PDF::Document.new
      doc.page do |page|
        rows = [
          ["a".as(PDF::Table::CellData), ({:content => "b", :valign => "bottom"} of Symbol => String | Int32 | Float64 | Bool?).as(PDF::Table::CellData)],
        ]
        table = page.table(rows, at: {50, 700}, cell_style: ({:padding => 3.0} of Symbol => String | Float64 | Bool?))
        table.cells[0][1].valign.should eq(:bottom)
        table.cells[0][0].padding.should eq([3.0, 3.0, 3.0, 3.0])
      end
    end

    it "accepts rows that mix strings, named tuples, images and tables" do
      doc = PDF::Document.new
      doc.page do |page|
        inner = PDF::Table.new(data: [["i"] of PDF::Table::CellData])
        table = page.table([["s", {content: "n", colspan: 2}], [png, inner, PDF::Table::Cell.new("c")]], at: {50, 700})
        table.column_count.should eq(3)
        table.cells[1][0].image.should_not be_nil
        table.cells[1][1].subtable.should be(inner)
      end
    end
  end
end

describe PDF::Table::Options do
  it "rejects per-side lists of the wrong size" do
    expect_raises(ArgumentError, /1, 2 or 4/) do
      PDF::Table::Options.normalize({padding: [1, 2, 3]})
    end
  end

  it "rejects lists for scalar options" do
    expect_raises(ArgumentError, /does not accept a list/) do
      PDF::Table::Options.normalize({font_size: [1, 2]})
    end
  end

  it "converts symbols and numbers" do
    PDF::Table::Options.normalize({align: :center, font_size: 9, border_width: 0.5}).should eq(
      Options{:align => "center", :font_size => 9, :border_width => 0.5})
  end
end
