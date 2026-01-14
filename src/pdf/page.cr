module PDF
  # Represents a single page in a PDF document.
  #
  # Pages contain content streams that describe what to draw,
  # and resources that are used by the content (fonts, images, etc.).
  #
  # ## Usage
  #
  # Pages are created via `Document#page`:
  #
  # ```
  # pdf.page do |page|
  #   page.font "Helvetica", size: 12
  #   page.text "Hello!", at: {72, 720}
  # end
  # ```
  class Page
    # Page dimensions in points
    getter width : Float64
    getter height : Float64

    # Parent document
    getter document : Document

    # Content operations buffer
    @content : IO::Memory

    # Current font name and size
    @current_font : String?
    @current_font_size : Float64 = 12.0

    # Current TrueType font (if using TrueType)
    @current_truetype_font : Fonts::TrueTypeFont?

    # Font resources used on this page (name -> reference)
    @font_resources : Hash(String, Objects::Reference)

    # TrueType font resources (font object -> resource data)
    @truetype_font_resources : Hash(Fonts::TrueTypeFont, TrueTypeFontResources)

    # Image resources used on this page (image object -> resource data)
    @image_resources : Hash(Images::Base, ImageResources)

    # Extended graphics state resources (ExtGState object -> resource data)
    @ext_g_state_resources : Hash(UInt64, ExtGStateResources)

    # The page's indirect object (set after finalization)
    @page_object : Objects::Indirect?

    # Content stream object
    @content_stream : Objects::Indirect?

    # Whether the page has been finalized
    @finalized : Bool = false

    # Resource data for a TrueType font on this page
    private struct TrueTypeFontResources
      getter font_ref : Objects::Reference?
      getter key : String

      def initialize(@font_ref : Objects::Reference?, @key : String)
      end
    end

    # Resource data for an image on this page
    private struct ImageResources
      getter image_ref : Objects::Reference?
      getter soft_mask_ref : Objects::Reference?
      getter key : String

      def initialize(@image_ref : Objects::Reference?, @soft_mask_ref : Objects::Reference?, @key : String)
      end
    end

    # Resource data for ExtGState on this page
    private struct ExtGStateResources
      getter ext_g_state : Objects::ExtGState
      getter ref : Objects::Reference?
      getter key : String

      def initialize(@ext_g_state : Objects::ExtGState, @ref : Objects::Reference?, @key : String)
      end
    end

    def initialize(@document : Document, @width : Float64 = 612.0, @height : Float64 = 792.0)
      @content = IO::Memory.new
      @font_resources = {} of String => Objects::Reference
      @truetype_font_resources = {} of Fonts::TrueTypeFont => TrueTypeFontResources
      @image_resources = {} of Images::Base => ImageResources
      @ext_g_state_resources = {} of UInt64 => ExtGStateResources
    end

    # Sets the current font for subsequent text operations.
    #
    # ```
    # page.font "Helvetica", size: 12
    # page.font "Helvetica-Bold", size: 18
    # ```
    def font(name : String, size : Number = 12) : self
      @current_font = name
      @current_font_size = size.to_f
      @current_truetype_font = nil

      # Register font with document and track resource
      font_obj = @document.font(name)
      unless @font_resources.has_key?(name)
        font_indirect = @document.register_object(font_obj.to_dictionary)
        @font_resources[name] = font_indirect.reference
      end

      self
    end

    # Sets the current font to a TrueType font.
    #
    # ```
    # my_font = pdf.load_font("./fonts/OpenSans-Regular.ttf")
    # page.font my_font, size: 12
    # page.text "Hello with custom font!", at: {72, 720}
    # ```
    def font(ttf_font : Fonts::TrueTypeFont, size : Number = 12) : self
      @current_font = ttf_font.name
      @current_font_size = size.to_f
      @current_truetype_font = ttf_font

      # Register TrueType font resources if not already done
      unless @truetype_font_resources.has_key?(ttf_font)
        register_truetype_font(ttf_font)
      end

      self
    end

    # Registers a TrueType font and creates all necessary PDF objects
    private def register_truetype_font(ttf_font : Fonts::TrueTypeFont) : Nil
      key = "F#{@font_resources.size + @truetype_font_resources.size + 1}"

      # We defer actual object creation until finalization
      # For now, just record that this font is used with nil reference
      @truetype_font_resources[ttf_font] = TrueTypeFontResources.new(
        nil, # Placeholder, set in finalize_truetype_fonts!
        key
      )
    end

    # Draws text at the specified position.
    #
    # Position is in points from the bottom-left corner of the page.
    #
    # ```
    # page.text "Hello, World!", at: {72, 720}
    # ```
    def text(content : String, *, at : Tuple(Number, Number)) : self
      font_name = @current_font
      raise "No font set. Call page.font first." unless font_name

      x, y = at

      # Handle TrueType fonts differently
      if ttf_font = @current_truetype_font
        font_key = @truetype_font_resources[ttf_font].key
        encoded_text = ttf_font.encode_text(content)

        @content << "BT\n"
        @content << "/#{font_key} #{format_number(@current_font_size)} Tf\n"
        @content << "#{format_number(x.to_f)} #{format_number(y.to_f)} Td\n"
        @content << encoded_text << " Tj\n"
        @content << "ET\n"
      else
        font_key = font_resource_key(font_name)

        # Build text content stream
        @content << "BT\n"                                                   # Begin text
        @content << "/#{font_key} #{format_number(@current_font_size)} Tf\n" # Set font
        @content << "#{format_number(x.to_f)} #{format_number(y.to_f)} Td\n" # Position
        @content << encode_text_string(content, font_name) << " Tj\n"        # Show text
        @content << "ET\n"                                                   # End text
      end

      self
    end

    # Draws an image at the specified position.
    #
    # Position is in points from the bottom-left corner of the page.
    # You can specify either width, height, or scale to control size.
    # If only width or height is given, aspect ratio is maintained.
    #
    # ```
    # image = PDF::Images::Image.load("photo.jpg")
    # page.image image, at: {72, 500}, width: 200
    # page.image image, at: {300, 500}, height: 150
    # page.image image, at: {72, 200}, scale: 0.5
    # ```
    def image(img : Images::Base, *, at : Tuple(Number, Number), width : Number? = nil, height : Number? = nil, scale : Number? = nil) : self
      x, y = at

      # Calculate display dimensions
      display_width, display_height = calculate_image_dimensions(img, width, height, scale)

      # Register image resource if not already done
      unless @image_resources.has_key?(img)
        register_image(img)
      end

      image_key = @image_resources[img].key

      # Draw image using transformation matrix
      # The 'Do' operator draws an XObject, but images are always 1x1 unit
      # so we need to scale to the desired size and translate to position
      @content << "q\n" # Save graphics state
      @content << "#{format_number(display_width.to_f)} 0 0 #{format_number(display_height.to_f)} "
      @content << "#{format_number(x.to_f)} #{format_number(y.to_f)} cm\n"
      @content << "/#{image_key} Do\n"
      @content << "Q\n" # Restore graphics state

      self
    end

    # Registers an image and prepares it for embedding
    private def register_image(img : Images::Base) : Nil
      key = "Im#{@image_resources.size + 1}"

      # We defer actual object creation until finalization
      @image_resources[img] = ImageResources.new(nil, nil, key)
    end

    # Calculate display dimensions for an image
    private def calculate_image_dimensions(img : Images::Base, width : Number?, height : Number?, scale : Number?) : Tuple(Float64, Float64)
      original_width = img.width.to_f
      original_height = img.height.to_f

      if scale
        # Scale both dimensions
        {original_width * scale.to_f, original_height * scale.to_f}
      elsif width && height
        # Explicit dimensions (may distort)
        {width.to_f, height.to_f}
      elsif width
        # Scale height to maintain aspect ratio
        ratio = width.to_f / original_width
        {width.to_f, original_height * ratio}
      elsif height
        # Scale width to maintain aspect ratio
        ratio = height.to_f / original_height
        {original_width * ratio, height.to_f}
      else
        # Use original dimensions
        {original_width, original_height}
      end
    end

    # Sets the stroke color (RGB, values 0.0 to 1.0).
    def stroke_color(r : Number, g : Number, b : Number) : self
      @content << "#{format_number(r.to_f)} #{format_number(g.to_f)} #{format_number(b.to_f)} RG\n"
      self
    end

    # Sets the fill color (RGB, values 0.0 to 1.0).
    def fill_color(r : Number, g : Number, b : Number) : self
      @content << "#{format_number(r.to_f)} #{format_number(g.to_f)} #{format_number(b.to_f)} rg\n"
      self
    end

    # Sets the stroke color using a named color.
    #
    # ```
    # page.stroke_color(:red)
    # page.stroke_color(:navy)
    # ```
    def stroke_color(name : Symbol) : self
      r, g, b = Content::Color.named(name)
      stroke_color(r, g, b)
    end

    # Sets the fill color using a named color.
    #
    # ```
    # page.fill_color(:blue)
    # page.fill_color(:orange)
    # ```
    def fill_color(name : Symbol) : self
      r, g, b = Content::Color.named(name)
      fill_color(r, g, b)
    end

    # Sets the stroke color from a hex string.
    #
    # ```
    # page.stroke_color("#FF0000")  # Red
    # page.stroke_color("#0F0")     # Green (short form)
    # ```
    def stroke_color(hex : String) : self
      r, g, b = Content::Color.from_hex(hex)
      stroke_color(r, g, b)
    end

    # Sets the fill color from a hex string.
    #
    # ```
    # page.fill_color("#0000FF")  # Blue
    # page.fill_color("#F0F")     # Magenta (short form)
    # ```
    def fill_color(hex : String) : self
      r, g, b = Content::Color.from_hex(hex)
      fill_color(r, g, b)
    end

    # Sets the stroke color (grayscale, 0.0 = black, 1.0 = white).
    #
    # ```
    # page.stroke_gray(0.5)  # 50% gray
    # ```
    def stroke_gray(gray : Number) : self
      @content << "#{format_number(gray.to_f)} G\n"
      self
    end

    # Sets the fill color (grayscale, 0.0 = black, 1.0 = white).
    #
    # ```
    # page.fill_gray(0.5)  # 50% gray
    # ```
    def fill_gray(gray : Number) : self
      @content << "#{format_number(gray.to_f)} g\n"
      self
    end

    # Sets the stroke color (CMYK, values 0.0 to 1.0).
    #
    # ```
    # page.stroke_cmyk(0.0, 1.0, 1.0, 0.0)  # Red in CMYK
    # ```
    def stroke_cmyk(c : Number, m : Number, y : Number, k : Number) : self
      @content << "#{format_number(c.to_f)} #{format_number(m.to_f)} "
      @content << "#{format_number(y.to_f)} #{format_number(k.to_f)} K\n"
      self
    end

    # Sets the fill color (CMYK, values 0.0 to 1.0).
    #
    # ```
    # page.fill_cmyk(1.0, 0.0, 0.0, 0.0)  # Cyan
    # ```
    def fill_cmyk(c : Number, m : Number, y : Number, k : Number) : self
      @content << "#{format_number(c.to_f)} #{format_number(m.to_f)} "
      @content << "#{format_number(y.to_f)} #{format_number(k.to_f)} k\n"
      self
    end

    # Sets the stroke color space.
    #
    # ```
    # page.stroke_color_space("DeviceRGB")
    # ```
    def stroke_color_space(name : String) : self
      @content << "/#{name} CS\n"
      self
    end

    # Sets the fill color space.
    #
    # ```
    # page.fill_color_space("DeviceCMYK")
    # ```
    def fill_color_space(name : String) : self
      @content << "/#{name} cs\n"
      self
    end

    # Sets the line width.
    def line_width(width : Number) : self
      @content << "#{format_number(width.to_f)} w\n"
      self
    end

    # Sets the line cap style.
    #
    # - `:butt` - Square end at endpoint (default)
    # - `:round` - Semicircular arc at endpoint
    # - `:square` - Square end extended half line width beyond endpoint
    #
    # ```
    # page.line_cap(:round)
    # page.line_cap(PDF::Content::GraphicsState::LineCap::Round)
    # ```
    def line_cap(style : Content::GraphicsState::LineCap) : self
      @content << "#{style.value} J\n"
      self
    end

    def line_cap(style : Symbol) : self
      cap = case style
            when :butt   then Content::GraphicsState::LineCap::Butt
            when :round  then Content::GraphicsState::LineCap::Round
            when :square then Content::GraphicsState::LineCap::Square
            else              raise ArgumentError.new("Unknown line cap: #{style}")
            end
      line_cap(cap)
    end

    # Sets the line join style.
    #
    # - `:miter` - Sharp corner (default)
    # - `:round` - Rounded corner
    # - `:bevel` - Beveled corner
    #
    # ```
    # page.line_join(:round)
    # page.line_join(PDF::Content::GraphicsState::LineJoin::Round)
    # ```
    def line_join(style : Content::GraphicsState::LineJoin) : self
      @content << "#{style.value} j\n"
      self
    end

    def line_join(style : Symbol) : self
      join = case style
             when :miter then Content::GraphicsState::LineJoin::Miter
             when :round then Content::GraphicsState::LineJoin::Round
             when :bevel then Content::GraphicsState::LineJoin::Bevel
             else             raise ArgumentError.new("Unknown line join: #{style}")
             end
      line_join(join)
    end

    # Sets the miter limit for line joins.
    # The miter limit controls when mitered joins are converted to bevel joins.
    # Default is 10.0.
    #
    # ```
    # page.miter_limit(5.0)
    # ```
    def miter_limit(limit : Number) : self
      @content << "#{format_number(limit.to_f)} M\n"
      self
    end

    # Sets the dash pattern for stroked lines.
    #
    # ```
    # # Solid line (default)
    # page.dash([])
    #
    # # Dashed: 5 on, 3 off
    # page.dash([5, 3])
    #
    # # Dash-dot: 6 on, 3 off, 1 on, 3 off
    # page.dash([6, 3, 1, 3])
    #
    # # With phase offset
    # page.dash([5, 3], phase: 2)
    # ```
    def dash(array : Array(Number), phase : Number = 0) : self
      arr_str = "[#{array.map { |v| format_number(v.to_f) }.join(" ")}]"
      @content << "#{arr_str} #{format_number(phase.to_f)} d\n"
      self
    end

    def dash(pattern : Content::GraphicsState::DashPattern) : self
      @content << "#{pattern.to_pdf} d\n"
      self
    end

    # Resets to solid line (no dash).
    def solid : self
      dash([] of Int32)
    end

    # Sets the rendering intent.
    #
    # ```
    # page.rendering_intent(:perceptual)
    # ```
    def rendering_intent(intent : Content::GraphicsState::RenderingIntent) : self
      @content << "/#{intent.to_pdf_name} ri\n"
      self
    end

    def rendering_intent(intent : Symbol) : self
      ri = case intent
           when :absolute_colorimetric then Content::GraphicsState::RenderingIntent::AbsoluteColorimetric
           when :relative_colorimetric then Content::GraphicsState::RenderingIntent::RelativeColorimetric
           when :saturation            then Content::GraphicsState::RenderingIntent::Saturation
           when :perceptual            then Content::GraphicsState::RenderingIntent::Perceptual
           else                             raise ArgumentError.new("Unknown rendering intent: #{intent}")
           end
      rendering_intent(ri)
    end

    # Sets the flatness tolerance.
    # Controls how smooth curves are rendered (0-100, default 0).
    #
    # ```
    # page.flatness(1)
    # ```
    def flatness(value : Number) : self
      @content << "#{format_number(value.to_f)} i\n"
      self
    end

    # Moves the current point to (x, y).
    def move_to(x : Number, y : Number) : self
      @content << "#{format_number(x.to_f)} #{format_number(y.to_f)} m\n"
      self
    end

    # Draws a line from the current point to (x, y).
    def line_to(x : Number, y : Number) : self
      @content << "#{format_number(x.to_f)} #{format_number(y.to_f)} l\n"
      self
    end

    # Draws a rectangle.
    def rectangle(x : Number, y : Number, width : Number, height : Number) : self
      @content << "#{format_number(x.to_f)} #{format_number(y.to_f)} "
      @content << "#{format_number(width.to_f)} #{format_number(height.to_f)} re\n"
      self
    end

    # Appends a cubic Bezier curve to the path.
    # Uses two control points and an endpoint.
    #
    # ```
    # page.move_to(100, 100)
    # page.curve_to(150, 200, 250, 200, 300, 100)  # Two control points, then endpoint
    # page.stroke
    # ```
    def curve_to(x1 : Number, y1 : Number, x2 : Number, y2 : Number, x3 : Number, y3 : Number) : self
      @content << "#{format_number(x1.to_f)} #{format_number(y1.to_f)} "
      @content << "#{format_number(x2.to_f)} #{format_number(y2.to_f)} "
      @content << "#{format_number(x3.to_f)} #{format_number(y3.to_f)} c\n"
      self
    end

    # Appends a cubic Bezier curve using current point as first control point.
    # The first control point is the current point.
    #
    # ```
    # page.move_to(100, 100)
    # page.curve_v(200, 150, 200, 100)  # Second control point, then endpoint
    # page.stroke
    # ```
    def curve_v(x2 : Number, y2 : Number, x3 : Number, y3 : Number) : self
      @content << "#{format_number(x2.to_f)} #{format_number(y2.to_f)} "
      @content << "#{format_number(x3.to_f)} #{format_number(y3.to_f)} v\n"
      self
    end

    # Appends a cubic Bezier curve with endpoint as second control point.
    # The second control point coincides with the endpoint.
    #
    # ```
    # page.move_to(100, 100)
    # page.curve_y(150, 150, 200, 100)  # First control point, then endpoint
    # page.stroke
    # ```
    def curve_y(x1 : Number, y1 : Number, x3 : Number, y3 : Number) : self
      @content << "#{format_number(x1.to_f)} #{format_number(y1.to_f)} "
      @content << "#{format_number(x3.to_f)} #{format_number(y3.to_f)} y\n"
      self
    end

    # Strokes the current path.
    def stroke : self
      @content << "S\n"
      self
    end

    # Fills the current path.
    def fill : self
      @content << "f\n"
      self
    end

    # Fills and strokes the current path.
    def fill_stroke : self
      @content << "B\n"
      self
    end

    # Closes the current subpath and strokes.
    def close_stroke : self
      @content << "s\n"
      self
    end

    # Fills the path using the even-odd rule.
    def fill_even_odd : self
      @content << "f*\n"
      self
    end

    # Fills (even-odd) and strokes the current path.
    def fill_stroke_even_odd : self
      @content << "B*\n"
      self
    end

    # Closes the path, fills, and strokes.
    def close_fill_stroke : self
      @content << "b\n"
      self
    end

    # Closes the path, fills (even-odd), and strokes.
    def close_fill_stroke_even_odd : self
      @content << "b*\n"
      self
    end

    # Ends the path without painting (used for clipping).
    def end_path : self
      @content << "n\n"
      self
    end

    # Closes the current subpath by drawing a line to the starting point.
    def close_path : self
      @content << "h\n"
      self
    end

    # Sets the clipping path using the non-zero winding rule.
    # Must be followed by a path painting operator (stroke, fill, or end_path).
    def clip : self
      @content << "W\n"
      self
    end

    # Sets the clipping path using the even-odd rule.
    # Must be followed by a path painting operator (stroke, fill, or end_path).
    def clip_even_odd : self
      @content << "W*\n"
      self
    end

    # Convenience: clips to the current path and ends the path.
    def clip! : self
      clip
      end_path
      self
    end

    # Convenience: clips (even-odd) to the current path and ends the path.
    def clip_even_odd! : self
      clip_even_odd
      end_path
      self
    end

    # Saves the graphics state.
    def save_graphics_state : self
      @content << "q\n"
      self
    end

    # Restores the graphics state.
    def restore_graphics_state : self
      @content << "Q\n"
      self
    end

    # Saves the graphics state, yields, then restores.
    def save_graphics_state(&block) : self
      save_graphics_state
      yield
      restore_graphics_state
      self
    end

    # ---------------------------------------------------------------------------
    # Transformation Methods
    # ---------------------------------------------------------------------------

    # Applies a transformation matrix to the current transformation matrix.
    # The transformation matrix is [a b c d e f], representing:
    # ```
    # | a  b  0 |
    # | c  d  0 |
    # | e  f  1 |
    # ```
    #
    # ```
    # # Translate by (100, 50)
    # page.transform(1, 0, 0, 1, 100, 50)
    # ```
    def transform(a : Number, b : Number, c : Number, d : Number, e : Number, f : Number) : self
      @content << "#{format_number(a.to_f)} #{format_number(b.to_f)} "
      @content << "#{format_number(c.to_f)} #{format_number(d.to_f)} "
      @content << "#{format_number(e.to_f)} #{format_number(f.to_f)} cm\n"
      self
    end

    # Translates the coordinate system by (tx, ty).
    #
    # ```
    # page.save_graphics_state do
    #   page.translate(100, 50)
    #   page.rectangle(0, 0, 50, 50)  # Draws at (100, 50)
    #   page.fill
    # end
    # ```
    def translate(tx : Number, ty : Number) : self
      transform(1, 0, 0, 1, tx, ty)
    end

    # Scales the coordinate system.
    #
    # ```
    # page.save_graphics_state do
    #   page.scale(2.0, 2.0)  # Double size
    #   page.rectangle(50, 50, 25, 25)  # Appears as 50x50 at (100, 100)
    #   page.fill
    # end
    # ```
    def scale(sx : Number, sy : Number) : self
      transform(sx, 0, 0, sy, 0, 0)
    end

    # Scales uniformly in both directions.
    def scale(s : Number) : self
      scale(s, s)
    end

    # Rotates the coordinate system by the given angle in degrees.
    # Rotation is counterclockwise.
    #
    # ```
    # page.save_graphics_state do
    #   page.translate(300, 400)
    #   page.rotate(45)
    #   page.rectangle(-25, -25, 50, 50)  # Rotated 45 degrees
    #   page.fill
    # end
    # ```
    def rotate(degrees : Number) : self
      radians = degrees.to_f * Math::PI / 180.0
      cos = Math.cos(radians)
      sin = Math.sin(radians)
      transform(cos, sin, -sin, cos, 0, 0)
    end

    # Skews the coordinate system.
    # `ax` is the skew angle in degrees along the X axis.
    # `ay` is the skew angle in degrees along the Y axis.
    #
    # ```
    # page.save_graphics_state do
    #   page.skew(15, 0)  # Skew along X axis
    #   page.rectangle(100, 100, 50, 50)
    #   page.fill
    # end
    # ```
    def skew(ax : Number, ay : Number) : self
      tan_ax = Math.tan(ax.to_f * Math::PI / 180.0)
      tan_ay = Math.tan(ay.to_f * Math::PI / 180.0)
      transform(1, tan_ay, tan_ax, 1, 0, 0)
    end

    # ---------------------------------------------------------------------------
    # Extended Graphics State
    # ---------------------------------------------------------------------------

    # Sets the fill opacity (0.0 = transparent, 1.0 = opaque).
    # This is a convenience method that uses ExtGState.
    #
    # ```
    # page.opacity(0.5)  # 50% opacity for fill
    # page.fill_color(:red)
    # page.rectangle(100, 100, 100, 100)
    # page.fill
    # ```
    def opacity(value : Number) : self
      gs = Objects::ExtGState.new
      gs.fill_opacity = value.to_f.clamp(0.0, 1.0)
      set_graphics_state(gs)
    end

    # Sets the stroke opacity (0.0 = transparent, 1.0 = opaque).
    #
    # ```
    # page.stroke_opacity(0.5)  # 50% opacity for stroke
    # page.stroke_color(:blue)
    # page.line_width(5)
    # page.rectangle(100, 100, 100, 100)
    # page.stroke
    # ```
    def stroke_opacity(value : Number) : self
      gs = Objects::ExtGState.new
      gs.stroke_opacity = value.to_f.clamp(0.0, 1.0)
      set_graphics_state(gs)
    end

    # Sets both fill and stroke opacity.
    #
    # ```
    # page.set_opacity(fill: 0.5, stroke: 0.8)
    # ```
    def set_opacity(fill : Number? = nil, stroke : Number? = nil) : self
      gs = Objects::ExtGState.new
      gs.fill_opacity = fill.to_f.clamp(0.0, 1.0) if fill
      gs.stroke_opacity = stroke.to_f.clamp(0.0, 1.0) if stroke
      set_graphics_state(gs)
    end

    # Sets the blend mode for compositing.
    #
    # ```
    # page.blend_mode(:multiply)
    # page.blend_mode(PDF::Content::GraphicsState::BlendMode::Screen)
    # ```
    def blend_mode(mode : Content::GraphicsState::BlendMode) : self
      gs = Objects::ExtGState.new
      gs.blend_mode = mode
      set_graphics_state(gs)
    end

    def blend_mode(mode : Symbol) : self
      bm = case mode
           when :normal      then Content::GraphicsState::BlendMode::Normal
           when :multiply    then Content::GraphicsState::BlendMode::Multiply
           when :screen      then Content::GraphicsState::BlendMode::Screen
           when :overlay     then Content::GraphicsState::BlendMode::Overlay
           when :darken      then Content::GraphicsState::BlendMode::Darken
           when :lighten     then Content::GraphicsState::BlendMode::Lighten
           when :color_dodge then Content::GraphicsState::BlendMode::ColorDodge
           when :color_burn  then Content::GraphicsState::BlendMode::ColorBurn
           when :hard_light  then Content::GraphicsState::BlendMode::HardLight
           when :soft_light  then Content::GraphicsState::BlendMode::SoftLight
           when :difference  then Content::GraphicsState::BlendMode::Difference
           when :exclusion   then Content::GraphicsState::BlendMode::Exclusion
           when :hue         then Content::GraphicsState::BlendMode::Hue
           when :saturation  then Content::GraphicsState::BlendMode::Saturation
           when :color       then Content::GraphicsState::BlendMode::Color
           when :luminosity  then Content::GraphicsState::BlendMode::Luminosity
           else                   raise ArgumentError.new("Unknown blend mode: #{mode}")
           end
      blend_mode(bm)
    end

    # Sets an extended graphics state.
    # The ExtGState will be registered as a resource and referenced.
    #
    # ```
    # gs = PDF::Objects::ExtGState.new
    # gs.fill_opacity = 0.5
    # gs.blend_mode = PDF::Content::GraphicsState::BlendMode::Multiply
    # page.set_graphics_state(gs)
    # ```
    def set_graphics_state(ext_g_state : Objects::ExtGState) : self
      key = register_ext_g_state(ext_g_state)
      @content << "/#{key} gs\n"
      self
    end

    # Registers an ExtGState and returns its resource key.
    private def register_ext_g_state(gs : Objects::ExtGState) : String
      hash = gs.hash_key

      unless @ext_g_state_resources.has_key?(hash)
        key = "GS#{@ext_g_state_resources.size + 1}"
        @ext_g_state_resources[hash] = ExtGStateResources.new(gs, nil, key)
      end

      @ext_g_state_resources[hash].key
    end

    # ---------------------------------------------------------------------------
    # Shape Helpers
    # ---------------------------------------------------------------------------

    # Draws a circle.
    # Uses cubic Bezier curves to approximate the circle.
    #
    # ```
    # page.fill_color(:blue)
    # page.circle(200, 300, 50)
    # page.fill
    # ```
    def circle(cx : Number, cy : Number, radius : Number) : self
      ellipse(cx, cy, radius, radius)
    end

    # Draws an ellipse.
    # Uses cubic Bezier curves to approximate the ellipse.
    #
    # ```
    # page.stroke_color(:red)
    # page.ellipse(200, 300, 80, 40)
    # page.stroke
    # ```
    def ellipse(cx : Number, cy : Number, rx : Number, ry : Number) : self
      # Magic number for Bezier curve approximation of a circle
      # This gives a maximum error of about 0.027% from a true circle
      kappa = 0.5522847498307936

      x = cx.to_f
      y = cy.to_f
      rx_f = rx.to_f
      ry_f = ry.to_f

      ox = rx_f * kappa # Control point offset horizontal
      oy = ry_f * kappa # Control point offset vertical

      # Start at the right side of the ellipse
      move_to(x + rx_f, y)

      # Top right quadrant
      curve_to(x + rx_f, y + oy, x + ox, y + ry_f, x, y + ry_f)

      # Top left quadrant
      curve_to(x - ox, y + ry_f, x - rx_f, y + oy, x - rx_f, y)

      # Bottom left quadrant
      curve_to(x - rx_f, y - oy, x - ox, y - ry_f, x, y - ry_f)

      # Bottom right quadrant
      curve_to(x + ox, y - ry_f, x + rx_f, y - oy, x + rx_f, y)

      close_path
      self
    end

    # Draws a polygon from an array of points.
    #
    # ```
    # # Triangle
    # page.polygon([{100, 100}, {150, 200}, {200, 100}])
    # page.fill_stroke
    # ```
    def polygon(points : Array(Tuple(Number, Number))) : self
      return self if points.empty?

      first = points.first
      move_to(first[0], first[1])

      points[1..].each do |point|
        line_to(point[0], point[1])
      end

      close_path
      self
    end

    # Draws a rounded rectangle.
    #
    # ```
    # page.fill_color(:green)
    # page.rounded_rectangle(100, 100, 200, 100, 10)
    # page.fill
    # ```
    def rounded_rectangle(x : Number, y : Number, w : Number, h : Number, radius : Number) : self
      x_f = x.to_f
      y_f = y.to_f
      w_f = w.to_f
      h_f = h.to_f
      r = radius.to_f

      # Clamp radius to half of minimum dimension
      r = Math.min(r, Math.min(w_f / 2, h_f / 2))

      # Bezier control point offset
      kappa = 0.5522847498307936
      c = r * kappa

      # Start at bottom-left, after the corner curve
      move_to(x_f + r, y_f)

      # Bottom edge
      line_to(x_f + w_f - r, y_f)

      # Bottom-right corner
      curve_to(x_f + w_f - r + c, y_f, x_f + w_f, y_f + r - c, x_f + w_f, y_f + r)

      # Right edge
      line_to(x_f + w_f, y_f + h_f - r)

      # Top-right corner
      curve_to(x_f + w_f, y_f + h_f - r + c, x_f + w_f - r + c, y_f + h_f, x_f + w_f - r, y_f + h_f)

      # Top edge
      line_to(x_f + r, y_f + h_f)

      # Top-left corner
      curve_to(x_f + r - c, y_f + h_f, x_f, y_f + h_f - r + c, x_f, y_f + h_f - r)

      # Left edge
      line_to(x_f, y_f + r)

      # Bottom-left corner
      curve_to(x_f, y_f + r - c, x_f + r - c, y_f, x_f + r, y_f)

      close_path
      self
    end

    # Draws an arc (portion of an ellipse).
    # Angles are in degrees, measured counterclockwise from the positive X axis.
    #
    # ```
    # page.arc(200, 200, 50, 0, 90)  # Quarter circle
    # page.stroke
    # ```
    def arc(cx : Number, cy : Number, radius : Number, start_angle : Number, end_angle : Number) : self
      arc_with_radii(cx, cy, radius, radius, start_angle, end_angle)
    end

    # Draws an elliptical arc.
    # Angles are in degrees, measured counterclockwise from the positive X axis.
    def arc_with_radii(cx : Number, cy : Number, rx : Number, ry : Number, start_angle : Number, end_angle : Number) : self
      x = cx.to_f
      y = cy.to_f
      rx_f = rx.to_f
      ry_f = ry.to_f

      # Convert to radians
      start_rad = start_angle.to_f * Math::PI / 180.0
      end_rad = end_angle.to_f * Math::PI / 180.0

      # Calculate start point
      start_x = x + rx_f * Math.cos(start_rad)
      start_y = y + ry_f * Math.sin(start_rad)
      move_to(start_x, start_y)

      # Split into 90-degree segments for accuracy
      angle_diff = end_rad - start_rad
      segments = (angle_diff.abs / (Math::PI / 2)).ceil.to_i
      segments = Math.max(1, segments)

      angle_per_segment = angle_diff / segments

      current_angle = start_rad
      segments.times do
        next_angle = current_angle + angle_per_segment
        draw_arc_segment(x, y, rx_f, ry_f, current_angle, next_angle)
        current_angle = next_angle
      end

      self
    end

    # Draws a single arc segment using a cubic Bezier curve.
    private def draw_arc_segment(cx : Float64, cy : Float64, rx : Float64, ry : Float64,
                                  start_angle : Float64, end_angle : Float64) : Nil
      # Calculate endpoints
      x1 = cx + rx * Math.cos(start_angle)
      y1 = cy + ry * Math.sin(start_angle)
      x4 = cx + rx * Math.cos(end_angle)
      y4 = cy + ry * Math.sin(end_angle)

      # Calculate tangent directions
      ax = -Math.sin(start_angle)
      ay = Math.cos(start_angle)
      bx = -Math.sin(end_angle)
      by = Math.cos(end_angle)

      # Calculate control point distance
      angle_diff = end_angle - start_angle
      k = 4.0 / 3.0 * Math.tan(angle_diff / 4.0)

      # Control points
      x2 = x1 + k * rx * ax
      y2 = y1 + k * ry * ay
      x3 = x4 - k * rx * bx
      y3 = y4 - k * ry * by

      curve_to(x2, y2, x3, y3, x4, y4)
    end

    # Draws a line from one point to another.
    #
    # ```
    # page.line({100, 100}, {200, 200})
    # page.stroke
    # ```
    def line(from : Tuple(Number, Number), to : Tuple(Number, Number)) : self
      move_to(from[0], from[1])
      line_to(to[0], to[1])
      self
    end

    # Finalizes the page, creating content stream and registering objects.
    # Called by Document#finalize!
    def finalize! : Nil
      return if @finalized
      @finalized = true

      # Register TrueType font objects
      finalize_truetype_fonts!

      # Register image objects
      finalize_images!

      # Register ExtGState objects
      finalize_ext_g_states!

      # Create content stream
      content_data = @content.to_s
      stream = Objects::Stream.new
      stream.data = content_data
      stream.add_filter(Filters::Flate.new) unless content_data.empty?

      @content_stream = @document.register_object(stream)
    end

    # Creates all PDF objects for TrueType fonts
    private def finalize_truetype_fonts! : Nil
      @truetype_font_resources.each do |ttf_font, resources|
        # Create font file stream (subset font data)
        font_file_stream = ttf_font.font_file_stream
        font_file_obj = @document.register_object(font_file_stream)

        # Create CIDToGIDMap stream (maps original GIDs to subset GIDs)
        cid_to_gid_map = ttf_font.cid_to_gid_map_stream
        cid_to_gid_obj = @document.register_object(cid_to_gid_map)

        # Create font descriptor
        descriptor = ttf_font.font_descriptor
        descriptor["FontFile2"] = font_file_obj.reference
        descriptor_obj = @document.register_object(descriptor)

        # Create ToUnicode CMap
        to_unicode = ttf_font.to_unicode_cmap
        to_unicode_obj = @document.register_object(to_unicode)

        # Create CIDFont dictionary
        cid_font = ttf_font.cid_font_dictionary
        cid_font["FontDescriptor"] = descriptor_obj.reference
        cid_font["CIDToGIDMap"] = cid_to_gid_obj.reference
        cid_font_obj = @document.register_object(cid_font)

        # Create Type0 font dictionary
        type0_font = ttf_font.to_dictionary
        descendants = Objects::Array.new
        descendants << cid_font_obj.reference
        type0_font["DescendantFonts"] = descendants
        type0_font["ToUnicode"] = to_unicode_obj.reference
        type0_font_obj = @document.register_object(type0_font)

        # Update the resource reference
        @truetype_font_resources[ttf_font] = TrueTypeFontResources.new(
          type0_font_obj.reference,
          resources.key
        )
      end
    end

    # Creates all PDF objects for images
    private def finalize_images! : Nil
      @image_resources.each do |img, resources|
        soft_mask_ref : Objects::Reference? = nil

        # Create soft mask stream first (if image has alpha)
        if img.has_alpha?
          if soft_mask_stream = img.soft_mask_stream
            soft_mask_obj = @document.register_object(soft_mask_stream)
            soft_mask_ref = soft_mask_obj.reference
          end
        end

        # Create main image stream
        image_stream = img.to_stream

        # Add soft mask reference if we have one
        if ref = soft_mask_ref
          image_stream["SMask"] = ref
        end

        image_obj = @document.register_object(image_stream)

        # Update the resource reference
        @image_resources[img] = ImageResources.new(
          image_obj.reference,
          soft_mask_ref,
          resources.key
        )
      end
    end

    # Creates all PDF objects for ExtGState
    private def finalize_ext_g_states! : Nil
      new_resources = {} of UInt64 => ExtGStateResources

      @ext_g_state_resources.each do |hash, resources|
        gs_dict = resources.ext_g_state.to_dictionary
        gs_obj = @document.register_object(gs_dict)

        new_resources[hash] = ExtGStateResources.new(
          resources.ext_g_state,
          gs_obj.reference,
          resources.key
        )
      end

      @ext_g_state_resources = new_resources
    end

    # Converts this page to an indirect object.
    def to_indirect_object(parent_ref : Objects::Reference) : Objects::Indirect
      finalize! unless @finalized

      dict = Objects::Dictionary.new
      dict["Type"] = Objects::Name::PAGE
      dict["Parent"] = parent_ref
      dict["MediaBox"] = Objects::Array.new([0, 0, @width.to_i, @height.to_i])

      # Add resources if we have any
      resources = build_resources
      dict["Resources"] = resources unless resources.empty?

      # Add content stream reference
      if content_stream = @content_stream
        dict["Contents"] = content_stream.reference
      end

      page_obj = @document.register_object(dict)
      @page_object = page_obj
      page_obj
    end

    private def build_resources : Objects::Dictionary
      resources = Objects::Dictionary.new

      # Add font resources
      has_fonts = !@font_resources.empty? || !@truetype_font_resources.empty?
      if has_fonts
        font_dict = Objects::Dictionary.new

        # Type1 fonts
        @font_resources.each do |name, ref|
          font_dict[font_resource_key(name)] = ref
        end

        # TrueType fonts
        @truetype_font_resources.each do |_, res|
          if ref = res.font_ref
            font_dict[res.key] = ref
          end
        end

        resources["Font"] = font_dict
      end

      # Add XObject resources (images)
      if !@image_resources.empty?
        xobject_dict = Objects::Dictionary.new

        @image_resources.each do |_, res|
          if ref = res.image_ref
            xobject_dict[res.key] = ref
          end
        end

        resources["XObject"] = xobject_dict unless xobject_dict.empty?
      end

      # Add ExtGState resources
      if !@ext_g_state_resources.empty?
        ext_g_state_dict = Objects::Dictionary.new

        @ext_g_state_resources.each do |_, res|
          if ref = res.ref
            ext_g_state_dict[res.key] = ref
          end
        end

        resources["ExtGState"] = ext_g_state_dict unless ext_g_state_dict.empty?
      end

      # ProcSet (required for some viewers)
      procset = Objects::Array.new
      procset << Objects::Name.new("PDF")
      procset << Objects::Name.new("Text")
      procset << Objects::Name.new("ImageC") if !@image_resources.empty?
      resources["ProcSet"] = procset

      resources
    end

    private def font_resource_key(font_name : String) : String
      # Create a simple key like F1, F2, etc.
      index = @font_resources.keys.index(font_name) || @font_resources.size
      "F#{index + 1}"
    end

    private def encode_text_string(text : String, font_name : String) : String
      # For Type1 fonts with WinAnsiEncoding, encode as literal string
      # TODO: Handle TrueType with proper encoding
      escaped = text.gsub("\\", "\\\\").gsub("(", "\\(").gsub(")", "\\)")
      "(#{escaped})"
    end

    private def format_number(value : Float64) : String
      if value == value.round
        value.to_i.to_s
      else
        "%.4f".%(value).rstrip('0').rstrip('.')
      end
    end
  end
end
