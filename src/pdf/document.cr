module PDF
  # Represents a PDF document.
  #
  # A PDF document consists of a collection of objects that describe
  # the structure and content of the document. The main components are:
  # - Catalog: The root of the document's object hierarchy
  # - Pages tree: A tree structure containing all pages
  # - Resources: Fonts, images, and other shared resources
  #
  # ## Basic Usage
  #
  # ```
  # pdf = PDF::Document.new
  #
  # pdf.page do |page|
  #   page.font "Helvetica", size: 12
  #   page.text "Hello, World!", at: {72, 720}
  # end
  #
  # pdf.save("output.pdf")
  # ```
  class Document
    # Default page size constants (in points, 72 points = 1 inch)
    PAGE_SIZES = {
      letter:    {612, 792},  # 8.5 x 11 inches
      a4:        {595, 842},  # 210 x 297 mm
      legal:     {612, 1008}, # 8.5 x 14 inches
      tabloid:   {792, 1224}, # 11 x 17 inches
      a3:        {842, 1191}, # 297 x 420 mm
      a5:        {420, 595},  # 148 x 210 mm
      executive: {522, 756},  # 7.25 x 10.5 inches
    }

    # All indirect objects in the document
    getter objects : Array(Objects::Indirect)

    # All pages in the document
    getter pages : Array(Page)

    # Document metadata
    property title : String?
    property author : String?
    property subject : String?
    property keywords : String?
    property creator : String?
    property producer : String = "pdf.cr #{PDF::VERSION}"

    # Next available object ID
    @next_object_id : Int32

    # Catalog object (document root)
    @catalog : Objects::Indirect?

    # Pages tree root
    @pages_root : Objects::Indirect?

    # Registered fonts (name -> font object)
    @fonts : Hash(String, Fonts::Base)

    # Loaded TrueType fonts (path -> font object)
    @truetype_fonts : Hash(String, Fonts::TrueTypeFont)

    def initialize
      @objects = [] of Objects::Indirect
      @pages = [] of Page
      @next_object_id = 1
      @fonts = {} of String => Fonts::Base
      @truetype_fonts = {} of String => Fonts::TrueTypeFont
    end

    # Creates a new page and yields it for content.
    #
    # ```
    # pdf.page do |page|
    #   page.text "Hello!", at: {72, 720}
    # end
    # ```
    def page(width : Number = 612, height : Number = 792, &block : Page ->) : Page
      page = Page.new(self, width.to_f, height.to_f)
      @pages << page
      yield page
      page
    end

    # Creates a new page with a named size.
    #
    # ```
    # pdf.page(size: :a4) do |page|
    #   page.text "A4 page", at: {72, 800}
    # end
    # ```
    def page(size : Symbol, orientation : Symbol = :portrait, &block : Page ->) : Page
      dimensions = PAGE_SIZES[size]? || raise ArgumentError.new("Unknown page size: #{size}")

      width, height = dimensions
      if orientation == :landscape
        width, height = height, width
      end

      page(width, height, &block)
    end

    # Allocates a new object ID.
    def allocate_object_id : Int32
      id = @next_object_id
      @next_object_id += 1
      id
    end

    # Registers an indirect object and returns it.
    def register_object(value : Objects::Base) : Objects::Indirect
      obj = Objects::Indirect.new(allocate_object_id, value)
      @objects << obj
      obj
    end

    # Gets or registers a font by name.
    def font(name : String) : Fonts::Base
      @fonts[name] ||= begin
        if Fonts::Type1::STANDARD_FONTS.includes?(name)
          font = Fonts::Type1.new(name)
          font
        else
          raise ArgumentError.new("Unknown font: #{name}. Use load_font to load TrueType fonts.")
        end
      end
    end

    # Loads a TrueType font from a file path.
    #
    # The font will be automatically subsetted to include only the glyphs
    # used in the document.
    #
    # ```
    # my_font = pdf.load_font("./fonts/OpenSans-Regular.ttf")
    # pdf.page do |page|
    #   page.font my_font, size: 12
    #   page.text "Hello!", at: {72, 720}
    # end
    # ```
    def load_font(path : String) : Fonts::TrueTypeFont
      @truetype_fonts[path] ||= Fonts::TrueTypeFont.load(path)
    end

    # Loads a TrueType font from bytes.
    def load_font(data : Bytes, name : String = "embedded") : Fonts::TrueTypeFont
      @truetype_fonts[name] ||= Fonts::TrueTypeFont.load(data)
    end

    # Gets all TrueType fonts used in this document.
    def truetype_fonts : Hash(String, Fonts::TrueTypeFont)
      @truetype_fonts
    end

    # Saves the document to a file.
    def save(path : String) : Nil
      File.open(path, "wb") do |file|
        write(file)
      end
    end

    # Writes the document to an IO.
    def write(io : IO) : Nil
      writer = Writer::DocumentWriter.new(self)
      writer.write(io)
    end

    # Returns the document as bytes.
    def to_slice : Bytes
      io = IO::Memory.new
      write(io)
      io.to_slice
    end

    # Builds and returns the catalog object.
    def catalog : Objects::Indirect
      @catalog ||= build_catalog
    end

    # Builds and returns the pages tree root.
    def pages_root : Objects::Indirect
      @pages_root ||= build_pages_tree
    end

    # Returns the document info dictionary, or nil if no metadata.
    def info_dict : Objects::Dictionary?
      dict = Objects::Dictionary.new

      dict["Title"] = Objects::Str.unicode(@title.not_nil!) if @title
      dict["Author"] = Objects::Str.unicode(@author.not_nil!) if @author
      dict["Subject"] = Objects::Str.unicode(@subject.not_nil!) if @subject
      dict["Keywords"] = Objects::Str.unicode(@keywords.not_nil!) if @keywords
      dict["Creator"] = Objects::Str.unicode(@creator.not_nil!) if @creator
      dict["Producer"] = Objects::Str.unicode(@producer)

      # Add creation date
      dict["CreationDate"] = Objects::Str.new(pdf_date(Time.utc))

      dict.empty? ? nil : dict
    end

    # Finalizes all pages and objects for writing.
    # Called by the writer before serialization.
    def finalize! : Nil
      # Finalize each page (creates content streams, registers resources)
      @pages.each(&.finalize!)

      # Build the pages tree
      pages_root

      # Build the catalog
      catalog
    end

    private def build_catalog : Objects::Indirect
      dict = Objects::Dictionary.new
      dict["Type"] = Objects::Name::CATALOG
      dict["Pages"] = pages_root.reference

      register_object(dict)
    end

    private def build_pages_tree : Objects::Indirect
      # Create the pages tree root
      pages_dict = Objects::Dictionary.new
      pages_dict["Type"] = Objects::Name::PAGES

      # Register pages tree first to get its reference
      pages_obj = register_object(pages_dict)

      # Build kids array with references to all pages
      kids = Objects::Array.new
      @pages.each do |page|
        page_obj = page.to_indirect_object(pages_obj.reference)
        kids << page_obj.reference
      end

      pages_dict["Kids"] = kids
      pages_dict["Count"] = Objects::Number.new(@pages.size)

      pages_obj
    end

    private def pdf_date(time : Time) : String
      # PDF date format: D:YYYYMMDDHHmmSSOHH'mm'
      # Example: D:20240115123045+00'00'
      offset = time.offset
      offset_hours = offset // 3600
      offset_minutes = (offset.abs % 3600) // 60
      sign = offset >= 0 ? "+" : "-"

      "D:#{time.to_s("%Y%m%d%H%M%S")}#{sign}#{offset_hours.abs.to_s.rjust(2, '0')}'#{offset_minutes.to_s.rjust(2, '0')}'"
    end
  end
end
