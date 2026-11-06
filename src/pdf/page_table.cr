module PDF
  class Page
    # Space kept free at the bottom and right edges of the page by
    # `#table`.
    TABLE_MARGIN = 50.0

    # Draws a table on the page at the specified position.
    #
    # Rows that do not fit flow onto new pages, and header rows repeat on
    # each new page. A cell is a string, a hash or named tuple of cell
    # options, an image, a nested `Table` or a `Table::Cell`. Use the
    # `image:` or `table:` key of a named tuple to set options on an image
    # or nested-table cell.
    #
    # Returns the table. Its `Table#end_page` and `Table#end_y` tell
    # where content can continue below the table.
    #
    # ```
    # table = page.table(
    #   [
    #     ["Header 1", "Header 2", "Header 3"],
    #     ["Cell 1", {content: "Cell 2", colspan: 2, valign: :center}],
    #   ],
    #   at: {50, 700},
    #   header: true,
    #   column_widths: [100.0, "30%", "30%"],
    #   cell_style: {padding: [4, 6], borders: [:bottom]},
    #   header_style: {background_color: "DDDDDD", font_style: :bold},
    # )
    # if (end_page = table.end_page) && (end_y = table.end_y)
    #   end_page.text("Below the table", at: {50, end_y - 20})
    # end
    # ```
    def table(
      data : Array,
      *,
      at : Tuple(Number, Number) = {0, 0},
      header : Bool | Int32 = false,
      column_widths : Array? = nil,
      table_width : Float64? = nil,
      cell_style : Hash | NamedTuple? = nil,
      row_colors : Array(String)? = nil,
      header_style : Hash | NamedTuple? = nil,
    ) : Table
      rows = data.map do |row|
        row.map { |cell| normalize_table_cell(cell).as(Table::CellData) }
      end

      x, y = at[0].to_f, at[1].to_f
      table = Table.new(
        data: rows,
        header: header,
        column_widths: column_widths,
        table_width: table_width,
        cell_style: cell_style,
        row_colors: row_colors,
        header_style: header_style,
        available_width: Math.max(@width - x - TABLE_MARGIN, 0.0),
      )

      page_width = @width
      page_height = @height

      table.draw_with_page_breaks(
        self,
        x: x,
        y: y,
        available_height: y - TABLE_MARGIN,
      ) do
        new_page = @document.page(page_width, page_height) { }
        {new_page, new_page.height - TABLE_MARGIN}
      end

      table
    end

    private def normalize_table_cell(cell : String | Table::Cell | Images::Base | Table) : Table::CellData
      cell
    end

    private def normalize_table_cell(cell : Hash | NamedTuple) : Table::CellData
      options, object = Table::Options.split(cell)
      object ? Table::Cell.make(object, options) : options
    end
  end
end
