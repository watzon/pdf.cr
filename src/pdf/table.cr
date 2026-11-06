require "./table/cell"

module PDF
  # A table renders tabular data as a grid of cells with borders,
  # padding, and optional styling. Supports colspan, rowspan, header
  # row repetition, and automatic column width calculation.
  #
  # Ported from Prawn::Table (prawn-table gem).
  #
  # ```
  # table = PDF::Table.new(
  #   data: [
  #     ["Header 1", "Header 2", "Header 3"],
  #     ["A", "B", "C"],
  #     ["D", "E", "F"],
  #   ],
  #   header: true,
  #   column_widths: [100.0, 200.0, 100.0],
  # )
  # table.draw(page, x: 50.0, y: 700.0)
  # ```
  class Table
    # Type alias for cell input data
    alias CellData = String | Hash(Symbol, String | Int32 | Float64 | Bool?)

    # The grid of cells (row-major order)
    getter cells : Array(Array(Cell))

    # Number of rows
    getter row_count : Int32

    # Number of columns
    getter column_count : Int32

    # Computed column widths
    getter column_widths : Array(Float64)

    # Computed row heights
    getter row_heights : Array(Float64)

    # Whether the first row(s) are headers to repeat on page breaks
    property header : Int32 = 0

    # Total table width (nil = auto)
    property table_width : Float64? = nil

    # Cell style defaults
    property cell_style : Hash(Symbol, String | Float64 | Bool?) = {} of Symbol => String | Float64 | Bool?

    # Row colors for alternating stripes
    property row_colors : Array(String)? = nil

    def initialize(
      data : Array(Array(CellData)),
      *,
      header : Bool | Int32 = false,
      column_widths : Array(Float64)? = nil,
      table_width : Float64? = nil,
      cell_style : Hash(Symbol, String | Float64 | Bool?)? = nil,
      row_colors : Array(String)? = nil,
    )
      @header = header.is_a?(Bool) ? (header ? 1 : 0) : header
      @table_width = table_width
      @row_colors = row_colors
      @cell_style = cell_style || {} of Symbol => String | Float64 | Bool?

      # Build cell grid from data
      @cells = build_cells(data)
      @row_count = @cells.size
      @column_count = @cells.empty? ? 0 : @cells.max_of(&.size)

      apply_row_colors

      # Set column widths
      if column_widths
        if column_widths.size != @column_count
          raise ArgumentError.new(
            "column_widths has #{column_widths.size} entries but the table has #{@column_count} columns")
        end
        @column_widths = column_widths
      else
        @column_widths = calculate_column_widths
      end

      # Calculate row heights
      @row_heights = calculate_row_heights
    end

    # Draws the table on the given page at the specified position.
    # Returns the y position after the table (for cursor tracking).
    def draw(page : Page, *, x : Float64, y : Float64) : Float64
      current_y = y

      # Position all cells
      position_cells(x, y)

      # Draw each row
      @cells.each_with_index do |row, row_idx|
        row.each do |cell|
          next if cell.span_dummy?
          draw_cell(page, cell)
        end
        current_y -= @row_heights[row_idx]
      end

      current_y
    end

    # Draws the table with header repetition across pages.
    # Yields when a new page is needed, expecting the caller to
    # create a new page and return it along with the new y position.
    def draw_with_page_breaks(
      page : Page,
      *,
      x : Float64,
      y : Float64,
      available_height : Float64,
      &block : -> Tuple(Page, Float64)
    ) : Tuple(Page, Float64)
      current_page = page
      current_y = y
      remaining_height = available_height
      # True right after a page break, until a body row is drawn. A group
      # that does not fit on a fresh page is drawn anyway (avoids a loop).
      fresh_page = false

      row_groups.each do |group|
        group_height = group.sum { |group_row| @row_heights[group_row] }

        if group_height > remaining_height && !fresh_page
          current_page, current_y = block.call
          remaining_height = current_y - 50.0 # margin
          fresh_page = true

          # Redraw header rows on new page (unless the header itself is
          # being drawn now)
          if @header > 0 && group.begin >= @header
            (0...@header).each do |header_row_idx|
              draw_row(current_page, header_row_idx, x, current_y)
              current_y -= @row_heights[header_row_idx]
              remaining_height -= @row_heights[header_row_idx]
            end
          end
        end

        group.each do |group_row|
          draw_row(current_page, group_row, x, current_y)
          current_y -= @row_heights[group_row]
          remaining_height -= @row_heights[group_row]
        end
        fresh_page = false
      end

      {current_page, current_y}
    end

    # Returns the total height of the table.
    def total_height : Float64
      @row_heights.sum
    end

    # Returns the total width of the table.
    def total_width : Float64
      @column_widths.sum
    end

    private def draw_row(page : Page, row_idx : Int32, x : Float64, y : Float64) : Nil
      position_row(row_idx, x, y)
      @cells[row_idx].each do |cell|
        next if cell.span_dummy?
        draw_cell(page, cell)
      end
    end

    # Groups of row indices that must stay on the same page (rows linked
    # by rowspan cells).
    private def row_groups : Array(Range(Int32, Int32))
      groups = [] of Range(Int32, Int32)
      i = 0
      while i < @row_count
        last = i
        j = i
        while j <= last
          @cells[j].each do |cell|
            next if cell.span_dummy?
            last = Math.max(last, Math.min(j + cell.rowspan - 1, @row_count - 1))
          end
          j += 1
        end
        groups << (i..last)
        i = last + 1
      end
      groups
    end

    private def build_cells(data : Array(Array(CellData))) : Array(Array(Cell))
      grid = [] of Array(Cell)

      data.each_with_index do |row_data, row_idx|
        row = [] of Cell
        col_idx = 0

        row_data.each do |cell_data|
          cell = Cell.make(cell_data)
          apply_cell_style(cell)
          cell.row = row_idx
          cell.column = col_idx

          row << cell

          # Create span dummies for colspan
          if cell.colspan > 1
            (1...cell.colspan).each do |col_offset|
              dummy = cell.create_span_dummy(row_idx, col_idx + col_offset)
              row << dummy
            end
          end

          col_idx += cell.colspan
        end

        grid << row
      end

      # Handle rowspan dummies
      grid.each_with_index do |row, row_idx|
        row.each_with_index do |cell, col_idx|
          next if cell.span_dummy?
          next if cell.rowspan <= 1

          (1...cell.rowspan).each do |row_offset|
            target_row = row_idx + row_offset
            next if target_row >= grid.size

            (0...cell.colspan).each do |col_offset|
              target_col = col_idx + col_offset
              dummy = cell.create_span_dummy(target_row, target_col)
              # Insert dummy at the right position
              if target_col < grid[target_row].size
                grid[target_row].insert(target_col, dummy)
              else
                grid[target_row] << dummy
              end
            end
          end
        end
      end

      grid
    end

    # Applies alternating row-stripe backgrounds from `row_colors`,
    # cycling per data row (header rows are excluded from striping).
    # A cell that already has an explicit background (from `cell_style`
    # or per-cell data) keeps it.
    private def apply_row_colors : Nil
      colors = @row_colors
      return unless colors
      return if colors.empty?

      stripe_idx = 0
      @cells.each_with_index do |row, row_idx|
        next if row_idx < @header

        color = colors[stripe_idx % colors.size]
        row.each do |cell|
          next if cell.span_dummy?
          cell.background_color ||= color
        end
        stripe_idx += 1
      end
    end

    private def apply_cell_style(cell : Cell) : Nil
      if fn = @cell_style[:font_name]?
        cell.font_name = fn.as(String)
      end
      if fs = @cell_style[:font_size]?
        cell.font_size = fs.as(Float64)
      end
      if tc = @cell_style[:text_color]?
        cell.text_color = tc.as(String)
      end
      if bg = @cell_style[:background_color]?
        cell.background_color = bg.as(String)
      end
      if bw = @cell_style[:border_width]?
        cell.border_width = bw.as(Float64)
      end
    end

    private def calculate_column_widths : Array(Float64)
      return [] of Float64 if @cells.empty?

      # Use equal distribution if no width specified
      if tw = @table_width
        equal_width = tw / @column_count
        Array.new(@column_count, equal_width)
      else
        # Calculate natural widths based on content
        widths = Array.new(@column_count, 0.0)

        @cells.each do |row|
          row.each_with_index do |cell, col_idx|
            next if cell.span_dummy?
            next if col_idx >= @column_count

            content_width = cell.natural_content_width
            cell_width = content_width + cell.padding_left + cell.padding_right

            if cell.colspan == 1
              widths[col_idx] = Math.max(widths[col_idx], cell_width)
            else
              # Distribute spanned width equally
              per_col = cell_width / cell.colspan
              (0...cell.colspan).each do |col_offset|
                target = col_idx + col_offset
                if target < @column_count
                  widths[target] = Math.max(widths[target], per_col)
                end
              end
            end
          end
        end

        # Ensure minimum width
        widths.map { |width| Math.max(width, 30.0) }
      end
    end

    private def calculate_row_heights : Array(Float64)
      return [] of Float64 if @cells.empty?

      heights = Array.new(@row_count, 0.0)

      @cells.each_with_index do |row, row_idx|
        row.each do |cell|
          next if cell.span_dummy?

          cell_height = cell.natural_height

          if cell.rowspan == 1
            heights[row_idx] = Math.max(heights[row_idx], cell_height)
          else
            # Distribute spanned height equally
            per_row = cell_height / cell.rowspan
            (0...cell.rowspan).each do |row_offset|
              target = row_idx + row_offset
              if target < @row_count
                heights[target] = Math.max(heights[target], per_row)
              end
            end
          end
        end
      end

      heights
    end

    private def position_cells(x : Float64, y : Float64) : Nil
      current_y = y

      @cells.each_with_index do |row, row_idx|
        current_x = x

        row.each_with_index do |cell, col_idx|
          cell.x = current_x
          cell.y = current_y

          # Calculate cell dimensions based on spans
          cell_width = 0.0
          (0...cell.colspan).each do |col_offset|
            target = col_idx + col_offset
            if target < @column_widths.size
              cell_width += @column_widths[target]
            end
          end
          cell.width = cell_width

          cell_height = 0.0
          (0...cell.rowspan).each do |row_offset|
            target = row_idx + row_offset
            if target < @row_heights.size
              cell_height += @row_heights[target]
            end
          end
          cell.height = cell_height

          if col_idx < @column_widths.size
            current_x += @column_widths[col_idx]
          end
        end

        current_y -= @row_heights[row_idx]
      end
    end

    private def position_row(row_idx : Int32, x : Float64, y : Float64) : Nil
      current_x = x

      @cells[row_idx].each_with_index do |cell, col_idx|
        cell.x = current_x
        cell.y = y

        cell_width = 0.0
        (0...cell.colspan).each do |col_offset|
          target = col_idx + col_offset
          if target < @column_widths.size
            cell_width += @column_widths[target]
          end
        end
        cell.width = cell_width

        cell_height = 0.0
        (0...cell.rowspan).each do |row_offset|
          target = row_idx + row_offset
          if target < @row_heights.size
            cell_height += @row_heights[target]
          end
        end
        cell.height = cell_height

        if col_idx < @column_widths.size
          current_x += @column_widths[col_idx]
        end
      end
    end

    private def draw_cell(page : Page, cell : Cell) : Nil
      return if cell.span_dummy?

      x = cell.x
      y = cell.y
      w = cell.width
      h = cell.height

      # Draw background
      if bg = cell.background_color
        page.fill_color(bg)
        page.rectangle(x, y - h, w, h)
        page.fill
      end

      # Draw borders
      if cell.border_width > 0
        page.stroke_color(cell.border_color)
        page.line_width(cell.border_width)

        if cell.borders.includes?(:top)
          page.move_to(x, y)
          page.line_to(x + w, y)
          page.stroke
        end
        if cell.borders.includes?(:bottom)
          page.move_to(x, y - h)
          page.line_to(x + w, y - h)
          page.stroke
        end
        if cell.borders.includes?(:left)
          page.move_to(x, y)
          page.line_to(x, y - h)
          page.stroke
        end
        if cell.borders.includes?(:right)
          page.move_to(x + w, y)
          page.line_to(x + w, y - h)
          page.stroke
        end
      end

      # Draw text content, one line per baseline
      unless cell.content.empty?
        page.fill_color(cell.text_color)
        page.font(cell.effective_font_name, size: cell.font_size)

        cell.lines.each_with_index do |line, i|
          next if line.empty?
          text_x = x + cell.padding_left
          text_y = y - cell.padding_top - cell.font_size - (i * cell.font_size * 1.2)

          case cell.align
          when :center
            text_x += (cell.content_width - cell.text_width(line)) / 2.0
          when :right
            text_x += cell.content_width - cell.text_width(line)
          end

          page.text(line, at: {text_x, text_y})
        end
      end

      # Reset fill color to black
      page.fill_color("000000")
    end
  end
end
