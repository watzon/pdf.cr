module PDF
  class Page
    # Draws a table on the page at the specified position.
    #
    # ```
    # page.table(
    #   [
    #     ["Header 1", "Header 2", "Header 3"],
    #     ["Cell 1", {content: "Cell 2", colspan: 2}],
    #   ],
    #   at: {50, 700},
    #   header: true,
    #   column_widths: [100.0, 150.0, 150.0],
    # )
    # ```
    def table(
      data : Array(Array(T)),
      *,
      at : Tuple(Number, Number) = {0, 0},
      header : Bool | Int32 = false,
      column_widths : Array(Float64)? = nil,
      table_width : Float64? = nil,
      cell_style : Hash(Symbol, String | Float64 | Bool?)? = nil,
      row_colors : Array(String)? = nil,
    ) : Table forall T
      rows = data.map do |row|
        row.map { |cell| normalize_table_cell(cell).as(Table::CellData) }
      end
      table(rows, at: at, header: header, column_widths: column_widths,
        table_width: table_width, cell_style: cell_style, row_colors: row_colors)
    end

    private def normalize_table_cell(cell : String) : Table::CellData
      cell
    end

    private def normalize_table_cell(cell : Hash | NamedTuple) : Table::CellData
      hash = {} of Symbol => String | Int32 | Float64 | Bool?
      cell.each do |key, value|
        hash[key] = case value
                    when Int               then value.to_i32
                    when Float             then value.to_f64
                    when String, Bool, Nil then value
                    else                        value.to_s
                    end
      end
      hash
    end

    def table(
      data : Array(Array(Table::CellData)),
      *,
      at : Tuple(Number, Number) = {0, 0},
      header : Bool | Int32 = false,
      column_widths : Array(Float64)? = nil,
      table_width : Float64? = nil,
      cell_style : Hash(Symbol, String | Float64 | Bool?)? = nil,
      row_colors : Array(String)? = nil,
    ) : Table
      table = Table.new(
        data: data,
        header: header,
        column_widths: column_widths,
        table_width: table_width,
        cell_style: cell_style,
        row_colors: row_colors,
      )

      margin_bottom = 50.0
      page_width = @width
      page_height = @height

      table.draw_with_page_breaks(
        self,
        x: at[0].to_f,
        y: at[1].to_f,
        available_height: at[1].to_f - margin_bottom,
      ) do
        new_page = @document.page(page_width, page_height) { }
        {new_page, new_page.height - margin_bottom}
      end

      table
    end
  end
end
