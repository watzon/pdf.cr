module PDF
  class Table
    # Represents a single cell in a table. A cell has content, position,
    # dimensions, padding, borders, and optional span.
    #
    # Ported from Prawn::Table::Cell.
    class Cell
      # Cell content (text string)
      property content : String

      # Row index in the table
      property row : Int32 = 0

      # Column index in the table
      property column : Int32 = 0

      # Number of columns this cell spans
      property colspan : Int32 = 1

      # Number of rows this cell spans
      property rowspan : Int32 = 1

      # Cell width (set during layout)
      property width : Float64 = 0.0

      # Cell height (set during layout)
      property height : Float64 = 0.0

      # Padding [top, right, bottom, left] in points
      property padding : Array(Float64) = [5.0, 5.0, 5.0, 5.0]

      # Borders to draw [:top, :bottom, :left, :right]
      property borders : Array(Symbol) = [:top, :bottom, :left, :right]

      # Border width in points
      property border_width : Float64 = 1.0

      # Border color in hex (e.g., "000000")
      property border_color : String = "000000"

      # Background color in hex (e.g., "CCCCCC"), nil for transparent
      property background_color : String? = nil

      # Text color in hex
      property text_color : String = "000000"

      # Font name
      property font_name : String = "Helvetica"

      # Font size
      property font_size : Float64 = 10.0

      # Text alignment
      property align : Symbol = :left

      # Whether this cell is bold
      property bold : Bool = false

      # Whether this cell is italic
      property italic : Bool = false

      # Whether this is a span dummy (placeholder for spanned cells)
      property span_dummy : Bool = false

      # Alias for span_dummy
      def span_dummy? : Bool
        @span_dummy
      end

      # The master cell for span dummies
      property master_cell : Cell? = nil

      # Absolute x position (set during layout)
      property x : Float64 = 0.0

      # Absolute y position (set during layout)
      property y : Float64 = 0.0

      def initialize(@content : String = "")
      end

      # Creates a cell from various input types.
      def self.make(content : String | Hash(Symbol, String | Int32 | Float64 | Bool | Nil) | Cell) : Cell
        case content
        when String
          Cell.new(content)
        when Cell
          content
        when Hash
          cell = Cell.new(content[:content]?.try(&.to_s) || "")
          if colspan = content[:colspan]?
            cell.colspan = colspan.as(Int32)
          end
          if rowspan = content[:rowspan]?
            cell.rowspan = rowspan.as(Int32)
          end
          if bg = content[:background_color]?
            cell.background_color = bg.as(String)
          end
          if tc = content[:text_color]?
            cell.text_color = tc.as(String)
          end
          if fn = content[:font_name]?
            cell.font_name = fn.as(String)
          end
          if fs = content[:font_size]?
            cell.font_size = fs.as(Float64)
          end
          # Note: align must be set separately as it's a Symbol
          # and the hash value type doesn't include Symbol
          if b = content[:bold]?
            cell.bold = b.as(Bool)
          end
          if i = content[:italic]?
            cell.italic = i.as(Bool)
          end
          cell
        else
          Cell.new(content.to_s)
        end
      end

      # Content width (width minus horizontal padding).
      def content_width : Float64
        @width - padding_left - padding_right
      end

      # Content height (height minus vertical padding).
      def content_height : Float64
        @height - padding_top - padding_bottom
      end

      # Natural content width based on text measurement.
      def natural_content_width(font_metrics : Proc(String, String, Float64, Float64)) : Float64
        effective_font = @font_name
        if @bold && @italic
          effective_font = "#{@font_name}-BoldOblique"
        elsif @bold
          effective_font = "#{@font_name}-Bold"
        elsif @italic
          effective_font = "#{@font_name}-Oblique"
        end
        font_metrics.call(@content, effective_font, @font_size)
      end

      # Natural height based on content and font size.
      def natural_height : Float64
        # Approximate: one line of text plus padding
        lines = @content.count('\n') + 1
        (lines * @font_size * 1.2) + padding_top + padding_bottom
      end

      # Padding accessors
      def padding_top : Float64
        @padding[0]
      end

      def padding_right : Float64
        @padding[1]
      end

      def padding_bottom : Float64
        @padding[2]
      end

      def padding_left : Float64
        @padding[3]
      end

      # Creates a SpanDummy cell for this cell's span group.
      def create_span_dummy(row : Int32, column : Int32) : Cell
        dummy = Cell.new("")
        dummy.row = row
        dummy.column = column
        dummy.master_cell = self
        dummy.borders = [] of Symbol
        dummy.padding = [0.0, 0.0, 0.0, 0.0]
        dummy.span_dummy = true
        dummy
      end
    end
  end
end
