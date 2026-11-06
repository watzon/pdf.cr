require "./options"

module PDF
  class Table
    # Represents a single cell in a table. A cell has content, position,
    # dimensions, padding, borders, and optional span.
    #
    # The content is text, an image (`#image`) or a nested table
    # (`#subtable`). Text wraps at word boundaries to the content width
    # once the cell has a width.
    #
    # Ported from Prawn::Table::Cell.
    class Cell
      @@measure_document = Document.new

      # Line height as a multiple of the font size.
      LINE_HEIGHT_FACTOR = 1.2

      # Tolerance for width comparisons, so that text in a column sized to
      # fit it does not wrap because of floating-point rounding.
      WIDTH_EPSILON = 1e-6

      # Cell content (text string)
      property content : String

      # Image content, drawn instead of text when set
      property image : Images::Base? = nil

      # Display width of the image in points (nil = from the image)
      property image_width : Float64? = nil

      # Display height of the image in points (nil = from the image)
      property image_height : Float64? = nil

      # Whether a wide image scales down to the content width
      property? image_fit : Bool = true

      # Nested table content, drawn instead of text when set
      property subtable : Table? = nil

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

      # Border width in points, for each side without its own width
      property border_width : Float64 = 1.0

      # Per-side border widths [top, right, bottom, left]; nil = `border_width`
      property border_widths : Array(Float64?) = [nil, nil, nil, nil] of Float64?

      # Border color in hex (e.g., "000000"), for each side without its own color
      property border_color : String = "000000"

      # Per-side border colors [top, right, bottom, left]; nil = `border_color`
      property border_colors : Array(String?) = [nil, nil, nil, nil] of String?

      # Background color in hex (e.g., "CCCCCC"), nil for transparent
      property background_color : String? = nil

      # Text color in hex
      property text_color : String = "000000"

      # Font name
      property font_name : String = "Helvetica"

      # Font size
      property font_size : Float64 = 10.0

      # Horizontal alignment (:left, :center, :right)
      property align : Symbol = :left

      # Vertical alignment (:top, :center, :bottom)
      property valign : Symbol = :top

      # Whether this cell is bold
      property? bold : Bool = false

      # Whether this cell is italic
      property? italic : Bool = false

      # Whether this is a span dummy (placeholder for spanned cells)
      property? span_dummy : Bool = false

      # The master cell for span dummies
      property master_cell : Cell? = nil

      # Absolute x position (set during layout)
      property x : Float64 = 0.0

      # Absolute y position (set during layout)
      property y : Float64 = 0.0

      # The options this cell got explicitly (through `.make` or
      # `#apply_options`). They take precedence over table styles.
      getter options : OptionHash = OptionHash.new

      def initialize(@content : String = "")
      end

      # Creates an image cell.
      def initialize(image : Images::Base)
        @content = ""
        @image = image
      end

      # Creates a cell that holds a nested table.
      def initialize(subtable : Table)
        @content = ""
        @subtable = subtable
      end

      # Creates a cell from various input types.
      def self.make(content : String | Hash(Symbol, String | Int32 | Float64 | Bool?) | Cell | Images::Base | Table) : Cell
        case content
        when String, Images::Base, Table
          Cell.new(content)
        when Cell
          content
        else
          Cell.new.apply_options(content)
        end
      end

      # Creates an image or nested-table cell with options.
      def self.make(content : Images::Base | Table, options : Hash | NamedTuple) : Cell
        Cell.new(content).apply_options(Options.normalize(options))
      end

      # Applies cell options and records them in `#options`. See
      # `Table::Options` for list values in named tuples.
      def apply_options(options : Hash(Symbol, String | Int32 | Float64 | Bool?)) : self
        @options.merge!(options)
        apply_style(options)
      end

      # Applies options without recording them (for table styles).
      def apply_style(options : Hash) : self
        @content = options[:content]?.to_s if options.has_key?(:content)
        apply_span_options(options)
        apply_color_options(options)
        apply_padding_options(options)
        apply_border_options(options)
        apply_font_options(options)
        apply_alignment_options(options)
        apply_image_options(options)
        self
      end

      private def apply_span_options(options : Hash) : Nil
        if colspan = Cell.to_int(options[:colspan]?)
          @colspan = colspan
        end
        if rowspan = Cell.to_int(options[:rowspan]?)
          @rowspan = rowspan
        end
      end

      private def apply_color_options(options : Hash) : Nil
        if bg = options[:background_color]?
          @background_color = bg.to_s
        end
        if tc = options[:text_color]?
          @text_color = tc.to_s
        end
      end

      private def apply_padding_options(options : Hash) : Nil
        if pad = Cell.to_float(options[:padding]?)
          @padding = [pad, pad, pad, pad]
        end
        Options::PADDING_KEYS.each_with_index do |key, side|
          if pad = Cell.to_float(options[key]?)
            @padding[side] = pad
          end
        end
      end

      private def apply_border_options(options : Hash) : Nil
        if list = options[:borders]?
          @borders = Cell.parse_borders(list.to_s)
        end
        if bw = Cell.to_float(options[:border_width]?)
          @border_width = bw
        end
        if bc = options[:border_color]?
          @border_color = bc.to_s
        end
        Options::SIDES.each_index do |side|
          if bw = Cell.to_float(options[Options::BORDER_WIDTH_KEYS[side]]?)
            @border_widths[side] = bw
          end
          if bc = options[Options::BORDER_COLOR_KEYS[side]]?
            @border_colors[side] = bc.to_s
          end
        end
      end

      private def apply_font_options(options : Hash) : Nil
        if fn = options[:font_name]?
          @font_name = fn.to_s
        end
        if fs = Cell.to_float(options[:font_size]?)
          @font_size = fs
        end
        if style = options[:font_style]?
          apply_font_style(style.to_s)
        end
        @bold = options[:bold]? == true if options.has_key?(:bold)
        @italic = options[:italic]? == true if options.has_key?(:italic)
      end

      private def apply_font_style(style : String) : Nil
        case style
        when "bold"        then @bold, @italic = true, false
        when "italic"      then @bold, @italic = false, true
        when "bold_italic" then @bold, @italic = true, true
        when "normal"      then @bold, @italic = false, false
        else
          raise ArgumentError.new("Unknown font_style #{style.inspect}: use normal, bold, italic or bold_italic")
        end
      end

      private def apply_alignment_options(options : Hash) : Nil
        case options[:align]?.to_s
        when "center" then @align = :center
        when "right"  then @align = :right
        when "left"   then @align = :left
        end
        case options[:valign]?.to_s
        when "top"              then @valign = :top
        when "center", "middle" then @valign = :center
        when "bottom"           then @valign = :bottom
        end
      end

      private def apply_image_options(options : Hash) : Nil
        if iw = Cell.to_float(options[:image_width]?)
          @image_width = iw
        end
        if ih = Cell.to_float(options[:image_height]?)
          @image_height = ih
        end
        @image_fit = options[:image_fit]? != false if options.has_key?(:image_fit)
      end

      # Parses a border list such as `"top bottom"`, `"all"` or `"none"`.
      protected def self.parse_borders(list : String) : Array(Symbol)
        names = list.split(/[\s,]+/, remove_empty: true)
        return [:top, :bottom, :left, :right] if names == ["all"]
        return [] of Symbol if names.empty? || names == ["none"]

        names.map do |name|
          Options::SIDES.find(&.to_s.==(name)) ||
            raise ArgumentError.new("Unknown border side #{name.inspect}: use top, right, bottom or left")
        end
      end

      # Coerces a numeric-like option value to Float64 (nil if not numeric).
      protected def self.to_float(value) : Float64?
        case value
        when Int32, Float64 then value.to_f
        when String         then value.to_f?
        end
      end

      # Coerces a numeric-like option value to Int32 (nil if not numeric).
      protected def self.to_int(value) : Int32?
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
        Text::Formatted::FontMeasurer.resolve_font_name(@font_name, styles)
      end

      # Width of a text string in this cell's font, using real font metrics.
      def text_width(text : String) : Float64
        return 0.0 if text.empty?
        @@measure_document.font(effective_font_name).string_width(text, @font_size)
      end

      # Distance between two text baselines.
      def line_height : Float64
        @font_size * LINE_HEIGHT_FACTOR
      end

      # Natural content width: the widest line of text, or the width of
      # the image or nested table, before wrapping or fitting.
      def natural_content_width : Float64
        if img = @image
          image_size(img, fit: false)[0]
        elsif table = @subtable
          table.total_width
        else
          lines.max_of? { |line| text_width(line) } || 0.0
        end
      end

      # Smallest content width that does not break a word or shrink the
      # content: the widest word, the width of an image that does not
      # fit, or the width of a nested table.
      def min_content_width : Float64
        if img = @image
          image_fit? ? 0.0 : image_size(img, fit: false)[0]
        elsif table = @subtable
          table.total_width
        else
          words = @content.split(/\s+/, remove_empty: true)
          words.max_of? { |word| text_width(word) } || 0.0
        end
      end

      # Content split into lines at explicit line breaks.
      def lines : Array(String)
        @content.split('\n', remove_empty: false)
      end

      # Content split into lines at explicit line breaks and wrapped to the
      # content width. Before layout (width 0), this is `#lines`.
      def wrapped_lines : Array(String)
        limit = content_width
        return lines if @width <= 0.0 || limit <= 0.0
        lines.flat_map { |line| wrap(line, limit) }
      end

      # Natural content height: the wrapped text, the image (fitted to the
      # content width) or the nested table.
      def natural_content_height : Float64
        if img = @image
          image_size(img, fit: true)[1]
        elsif table = @subtable
          table.total_height
        else
          wrapped_lines.size * line_height
        end
      end

      # Natural height based on content and padding.
      def natural_height : Float64
        natural_content_height + padding_top + padding_bottom
      end

      # Display size of the image content. With *fit*, an image wider than
      # the content width scales down to it (if `#image_fit?`).
      def image_size(img : Images::Base, *, fit : Bool) : Tuple(Float64, Float64)
        w, h = natural_image_size(img)
        limit = content_width
        if fit && image_fit? && @width > 0.0 && w > limit && limit > 0.0
          h = h * limit / w
          w = limit
        end
        {w, h}
      end

      private def natural_image_size(img : Images::Base) : Tuple(Float64, Float64)
        iw = @image_width
        ih = @image_height
        if iw && ih
          {iw, ih}
        elsif iw
          {iw, img.height * iw / img.width}
        elsif ih
          {img.width * ih / img.height, ih}
        else
          {img.width.to_f, img.height.to_f}
        end
      end

      # Greedy word wrap. A line that fits stays unchanged (with its
      # spaces). A word wider than *limit* breaks between characters.
      private def wrap(line : String, limit : Float64) : Array(String)
        return [line] if fits?(line, limit)

        result = [] of String
        current = ""
        line.split(' ', remove_empty: true).each do |word|
          candidate = current.empty? ? word : "#{current} #{word}"
          if fits?(candidate, limit)
            current = candidate
          else
            result << current unless current.empty?
            current = break_word(word, limit, result)
          end
        end
        result << current
        result
      end

      # Moves pieces of *word* that fill a whole line into *result* and
      # returns the rest.
      private def break_word(word : String, limit : Float64, result : Array(String)) : String
        rest = word
        while rest.size > 1 && !fits?(rest, limit)
          count = 1
          while count < rest.size - 1 && fits?(rest[0, count + 1], limit)
            count += 1
          end
          result << rest[0, count]
          rest = rest[count..]
        end
        rest
      end

      private def fits?(text : String, limit : Float64) : Bool
        text_width(text) <= limit + WIDTH_EPSILON
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

      # Border width of one side (:top, :right, :bottom or :left).
      def border_width_for(side : Symbol) : Float64
        @border_widths[Options::SIDES.index!(side)] || @border_width
      end

      # Border color of one side (:top, :right, :bottom or :left).
      def border_color_for(side : Symbol) : String
        @border_colors[Options::SIDES.index!(side)] || @border_color
      end

      # Draws the background, borders and content at the cell position.
      def draw(page : Page) : Nil
        return if span_dummy?

        draw_background(page)
        draw_borders(page)

        offset = vertical_offset
        if img = @image
          draw_image(page, img, offset)
        elsif table = @subtable
          table.draw(page, x: @x + padding_left + horizontal_offset(table.total_width), y: @y - padding_top - offset)
        else
          draw_text(page, offset)
        end
      end

      private def draw_background(page : Page) : Nil
        bg = @background_color
        return unless bg

        page.fill_color(bg)
        page.rectangle(@x, @y - @height, @width, @height)
        page.fill
        page.fill_color("000000")
      end

      private def draw_borders(page : Page) : Nil
        top, bottom = @y, @y - @height
        left, right = @x, @x + @width
        draw_border(page, :top, {left, top}, {right, top})
        draw_border(page, :bottom, {left, bottom}, {right, bottom})
        draw_border(page, :left, {left, top}, {left, bottom})
        draw_border(page, :right, {right, top}, {right, bottom})
      end

      private def draw_border(page : Page, side : Symbol, from : Tuple(Float64, Float64), to : Tuple(Float64, Float64)) : Nil
        return unless @borders.includes?(side)
        width = border_width_for(side)
        return unless width > 0

        page.stroke_color(border_color_for(side))
        page.line_width(width)
        page.move_to(*from)
        page.line_to(*to)
        page.stroke
      end

      private def draw_image(page : Page, img : Images::Base, offset : Float64) : Nil
        w, h = image_size(img, fit: true)
        page.image(img, at: {@x + padding_left + horizontal_offset(w), @y - padding_top - offset - h}, width: w, height: h)
      end

      private def draw_text(page : Page, offset : Float64) : Nil
        return if @content.empty?

        page.fill_color(@text_color)
        page.font(effective_font_name, size: @font_size)

        wrapped_lines.each_with_index do |line, i|
          next if line.empty?
          text_x = @x + padding_left + horizontal_offset(text_width(line))
          text_y = @y - padding_top - offset - @font_size - (i * line_height)
          page.text(line, at: {text_x, text_y})
        end

        page.fill_color("000000")
      end

      # Offset from the left content edge for content of *width*.
      private def horizontal_offset(width : Float64) : Float64
        case @align
        when :center then (content_width - width) / 2.0
        when :right  then content_width - width
        else              0.0
        end
      end

      # Offset from the top content edge for `#valign`. Content taller
      # than the cell stays at the top.
      private def vertical_offset : Float64
        free = content_height - natural_content_height
        return 0.0 if free <= 0.0

        case @valign
        when :center then free / 2.0
        when :bottom then free
        else              0.0
        end
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
