module PDF
  class Page
    # Draws a table on the page at the specified position.
    #
    # ```
    # page.table(
    #   [
    #     ["Header 1", "Header 2"],
    #     ["Cell 1", {content: "Cell 2", colspan: 2}],
    #   ],
    #   at: {50, 700},
    #   header: true,
    #   column_widths: [100.0, 200.0],
    # )
    # ```
    def table(
      data : Array(Array(Table::CellData)),
      *,
      at : Tuple(Number, Number) = {0, 0},
      header : Bool | Int32 = false,
      column_widths : Array(Float64)? = nil,
      table_width : Float64? = nil,
      cell_style : Hash(Symbol, String | Float64 | Bool | Nil)? = nil,
      row_colors : Array(String)? = nil
    ) : Table
      table = Table.new(
        data: data,
        header: header,
        column_widths: column_widths,
        table_width: table_width,
        cell_style: cell_style,
        row_colors: row_colors,
      )
      table.draw(self, x: at[0].to_f, y: at[1].to_f)
      table
    end
  end
end
