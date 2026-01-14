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

    def initialize(@document : Document, @width : Float64 = 612.0, @height : Float64 = 792.0)
      @content = IO::Memory.new
      @font_resources = {} of String => Objects::Reference
      @truetype_font_resources = {} of Fonts::TrueTypeFont => TrueTypeFontResources
      @image_resources = {} of Images::Base => ImageResources
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

    # Sets the line width.
    def line_width(width : Number) : self
      @content << "#{format_number(width.to_f)} w\n"
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

    # Finalizes the page, creating content stream and registering objects.
    # Called by Document#finalize!
    def finalize! : Nil
      return if @finalized
      @finalized = true

      # Register TrueType font objects
      finalize_truetype_fonts!

      # Register image objects
      finalize_images!

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
