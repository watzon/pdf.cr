module PDF
  class Table
    # Exposes FontMeasurer's standard-14 bold/italic name mapping.
    class StyleResolver < Text::Formatted::FontMeasurer
      def resolve(base_name : String, styles : Array(Symbol)) : String
        resolve_font_name(base_name, styles)
      end
    end

    # Represents a single cell in a table. A cell has content, position,
    # dimensions, padding, borders, and optional span.
    #
    # Ported from Prawn::Table::Cell.
    class Cell
      @@measure_document = Document.new

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
          if colspan = to_int(content[:colspan]?)
            cell.colspan = colspan
          end
          if rowspan = to_int(content[:rowspan]?)
            cell.rowspan = rowspan
          end
          if bg = content[:background_color]?
            cell.background_color = bg.to_s
          end
          if tc = content[:text_color]?
            cell.text_color = tc.to_s
          end
          if bc = content[:border_color]?
            cell.border_color = bc.to_s
          end
          if fn = content[:font_name]?
            cell.font_name = fn.to_s
          end
          if fs = to_float(content[:font_size]?)
            cell.font_size = fs
          end
          if bw = to_float(content[:border_width]?)
            cell.border_width = bw
          end
          if pad = to_float(content[:padding]?)
            cell.padding = [pad, pad, pad, pad]
          end
          if al = content[:align]?
            case al.to_s
            when "center" then cell.align = :center
            when "right"  then cell.align = :right
            when "left"   then cell.align = :left
            end
          end
          if b = content[:bold]?
            cell.bold = b == true
          end
          if i = content[:italic]?
            cell.italic = i == true
          end
          cell
        else
          Cell.new(content.to_s)
        end
      end

      # Coerces a numeric-like option value to Float64 (nil if not numeric).
      private def self.to_float(value) : Float64?
        case value
        when Int32, Float64 then value.to_f
        when String         then value.to_f?
        end
      end

      # Coerces a numeric-like option value to Int32 (nil if not numeric).
      private def self.to_int(value) : Int32?
        case value
        when Int32   then value
        when Float64 then value.to_i
        when String  then value.to_i?
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

      # Font name with bold/italic applied (standard-14 variants).
      def effective_font_name : String
        styles = [] of Symbol
        styles << :bold if @bold
        styles << :italic if @italic
        return @font_name if styles.empty?
        StyleResolver.new(@@measure_document).resolve(@font_name, styles)
      end

      # Width of a text string in this cell's font, using real font metrics.
      def text_width(text : String) : Float64
        return 0.0 if text.empty?
        @@measure_document.font(effective_font_name).string_width(text, @font_size)
      end

      # Natural content width: the widest line of the content.
      def natural_content_width : Float64
        lines.max_of? { |line| text_width(line) } || 0.0
      end

      # Content split into lines.
      def lines : Array(String)
        @content.split('\n', remove_empty: false)
      end

      # Natural height based on content and font size.
      def natural_height : Float64
        # Approximate: one line of text plus padding
        (lines.size * @font_size * 1.2) + padding_top + padding_bottom
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
