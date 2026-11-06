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
    # Type alias for cell input data. A `Cell` is used as given, then
    # table styles apply to it and its recorded `Cell#options` apply again.
    alias CellData = String | Hash(Symbol, String | Int32 | Float64 | Bool?) | Cell | Images::Base | Table

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

    # Width that percentage column widths refer to when `table_width` is
    # nil. Auto column widths shrink to fit in it.
    getter available_width : Float64? = nil

    # Cell style defaults
    property cell_style : Hash(Symbol, String | Float64 | Bool?) = {} of Symbol => String | Float64 | Bool?

    # Style for header rows, applied after `cell_style`
    getter header_style : Hash(Symbol, String | Float64 | Bool?) = {} of Symbol => String | Float64 | Bool?

    # Row colors for alternating stripes
    property row_colors : Array(String)? = nil

    # The page that holds the end of the table after the last draw
    # (nil before the table is drawn).
    getter end_page : Page? = nil

    # The y position below the last row after the last draw (nil before
    # the table is drawn). Content can continue below the table from
    # here on `end_page`.
    getter end_y : Float64? = nil

    # Minimum width of an auto-sized column.
    MIN_COLUMN_WIDTH = 30.0

    # Creates a table.
    #
    # - *column_widths*: one entry per column. A number is a width in
    #   points. A string such as `"25%"` is a percentage of
    #   *table_width* (or of *available_width* if *table_width* is nil).
    # - *cell_style* and *header_style*: hashes or named tuples of cell
    #   options (see `Table::Options`). Options a cell sets itself win.
    # - *available_width*: the space the table can use. Auto column
    #   widths shrink to fit in it, and percentages use it as a basis.
    def initialize(
      data : Array(Array(CellData)),
      *,
      header : Bool | Int32 = false,
      column_widths : Array? = nil,
      table_width : Float64? = nil,
      cell_style : Hash | NamedTuple? = nil,
      row_colors : Array(String)? = nil,
      header_style : Hash | NamedTuple? = nil,
      available_width : Float64? = nil,
    )
      @header = header.is_a?(Bool) ? (header ? 1 : 0) : header
      @table_width = table_width
      @available_width = available_width
      @row_colors = row_colors
      @cell_style = Options.to_style(Options.normalize(cell_style)) if cell_style
      @header_style = Options.to_style(Options.normalize(header_style)) if header_style

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
        @column_widths = column_widths.map { |width| resolve_column_width(width) }
      else
        @column_widths = calculate_column_widths
      end

      # Text wraps to the cell widths, so widths come before heights
      assign_cell_widths
      @row_heights = calculate_row_heights
    end

    # Draws the table on the given page at the specified position.
    # Returns the y position after the table (for cursor tracking).
    # Also sets `end_page` and `end_y`.
    def draw(page : Page, *, x : Float64, y : Float64) : Float64
      current_y = y
      @row_count.times do |row_idx|
        draw_row(page, row_idx, x, current_y)
        current_y -= @row_heights[row_idx]
      end

      @end_page = page
      @end_y = current_y
    end

    # Draws the table with header repetition across pages.
    # Yields when a new page is needed, expecting the caller to
    # create a new page and return it along with the new y position.
    # Returns the last page and the y position below the table, and sets
    # `end_page` and `end_y` to them.
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

      @end_page = current_page
      @end_y = current_y
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
      @cells[row_idx].each(&.draw(page))
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
          cell = make_cell(cell_data, row_idx)
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

    # Builds a cell with the precedence cell_style < header_style <
    # the cell's own options.
    private def make_cell(data : CellData, row_idx : Int32) : Cell
      cell = Cell.make(data)
      cell.apply_style(@cell_style)
      cell.apply_style(@header_style) if row_idx < @header
      cell.apply_style(cell.options)
    end

    # Resolves one `column_widths` entry to points.
    private def resolve_column_width(width : Number) : Float64
      width.to_f
    end

    private def resolve_column_width(width : String) : Float64
      percent = width.strip.rchop("%").to_f?
      unless width.strip.ends_with?('%') && percent && percent >= 0
        raise ArgumentError.new("Column width #{width.inspect} is not a percentage such as \"25%\"")
      end
      basis = @table_width || @available_width ||
              raise ArgumentError.new("Percentage column width #{width.inspect} needs table_width or available_width")
      basis * percent / 100.0
    end

    private def resolve_column_width(width) : Float64
      raise ArgumentError.new("Column width #{width.inspect} must be a number or a percentage string")
    end

    private def calculate_column_widths : Array(Float64)
      return [] of Float64 if @cells.empty?

      # Use equal distribution if no width specified
      if tw = @table_width
        equal_width = tw / @column_count
        return Array.new(@column_count, equal_width)
      end

      # Natural widths from content, with a minimum width
      widths = column_extents(&.natural_content_width).map { |width| Math.max(width, MIN_COLUMN_WIDTH) }
      limit = @available_width
      return widths unless limit && widths.sum > limit

      mins = column_extents(&.min_content_width)
      shrink_to_fit(widths, mins.map_with_index { |min, i| Math.min(widths[i], Math.max(min, MIN_COLUMN_WIDTH)) }, limit)
    end

    # The widest cell extent (content width from the block plus horizontal
    # padding) of each column. A spanning cell counts equally in each of
    # its columns.
    private def column_extents(& : Cell -> Float64) : Array(Float64)
      widths = Array.new(@column_count, 0.0)

      @cells.each do |row|
        row.each_with_index do |cell, col_idx|
          next if cell.span_dummy?

          per_col = (yield(cell) + cell.padding_left + cell.padding_right) / cell.colspan
          (col_idx...Math.min(col_idx + cell.colspan, @column_count)).each do |target|
            widths[target] = Math.max(widths[target], per_col)
          end
        end
      end

      widths
    end

    # Shrinks *widths* to a sum of *limit*. Each column gives up space in
    # proportion to how far it is above its minimum. If the minimums do
    # not fit, the result is the minimums.
    private def shrink_to_fit(widths : Array(Float64), mins : Array(Float64), limit : Float64) : Array(Float64)
      excess = widths.sum - limit
      slack = widths.zip(mins).sum { |width, min| width - min }
      return mins if slack <= excess

      widths.map_with_index { |width, i| width - (width - mins[i]) * excess / slack }
    end

    # Sets each cell width from the column widths it spans.
    private def assign_cell_widths : Nil
      @cells.each do |row|
        row.each_with_index do |cell, col_idx|
          last = Math.min(col_idx + cell.colspan, @column_widths.size)
          cell.width = (col_idx...last).sum { |target| @column_widths[target] }
        end
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

    # Sets the position and height of each cell in a row. Widths come
    # from `assign_cell_widths`.
    private def position_row(row_idx : Int32, x : Float64, y : Float64) : Nil
      current_x = x

      @cells[row_idx].each_with_index do |cell, col_idx|
        cell.x = current_x
        cell.y = y

        last = Math.min(row_idx + cell.rowspan, @row_heights.size)
        cell.height = (row_idx...last).sum { |target| @row_heights[target] }

        if col_idx < @column_widths.size
          current_x += @column_widths[col_idx]
        end
      end
    end
  end
end
