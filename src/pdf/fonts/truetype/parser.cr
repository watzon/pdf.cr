module PDF
  module Fonts
    module TrueType
      # Error raised when parsing a TrueType font fails
      class ParseError < Exception
      end

      # TrueType/OpenType font parser.
      # Parses .ttf and .otf font files and provides access to font data.
      class Parser
        include IOHelpers

        # Raw font data
        getter data : Bytes

        # Table records
        getter table_records : Hash(String, TableRecord)

        # Parsed tables (lazy loaded)
        @head : Tables::Head?
        @hhea : Tables::Hhea?
        @maxp : Tables::Maxp?
        @hmtx : Tables::Hmtx?
        @cmap : Tables::Cmap?
        @loca : Tables::Loca?
        @glyf : Tables::Glyf?
        @name : Tables::Name?
        @post : Tables::Post?
        @os2 : Tables::OS2?

        # Font type (TrueType or CFF)
        getter sfnt_version : UInt32

        def initialize(@data : Bytes, @table_records : Hash(String, TableRecord), @sfnt_version : UInt32)
        end

        # Parse a TrueType font from a file path
        def self.parse(path : String) : Parser
          parse(File.read(path).to_slice)
        end

        # Parse a TrueType font from bytes
        def self.parse(data : Bytes) : Parser
          raise ParseError.new("Font data is too small") if data.size < 12

          io = IO::Memory.new(data)

          # Read sfnt version
          sfnt_version = read_uint32(io)

          # Validate sfnt version
          unless valid_sfnt_version?(sfnt_version)
            raise ParseError.new("Invalid sfnt version: 0x#{sfnt_version.to_s(16)}")
          end

          # Read table directory
          num_tables = read_uint16(io)
          _search_range = read_uint16(io)
          _entry_selector = read_uint16(io)
          _range_shift = read_uint16(io)

          # Read table records
          table_records = Hash(String, TableRecord).new
          num_tables.times do
            record = TableRecord.parse(io)
            table_records[record.tag] = record
          end

          new(data, table_records, sfnt_version)
        end

        # Check if the sfnt version is valid
        private def self.valid_sfnt_version?(version : UInt32) : Bool
          version == 0x00010000 ||        # TrueType
            version == 0x4F54544F ||       # 'OTTO' (CFF)
            version == 0x74727565 ||       # 'true' (Apple TrueType)
            version == 0x74797031          # 'typ1' (Type 1)
        end

        # Check if this is a TrueType font (glyf outlines)
        def truetype? : Bool
          @sfnt_version == 0x00010000 || @sfnt_version == 0x74727565
        end

        # Check if this is a CFF font
        def cff? : Bool
          @sfnt_version == 0x4F54544F
        end

        # Check if a table exists
        def has_table?(tag : String) : Bool
          @table_records.has_key?(tag)
        end

        # Get raw table data
        def table_data(tag : String) : Bytes?
          record = @table_records[tag]?
          return nil unless record

          start_offset = record.offset.to_i
          end_offset = start_offset + record.length.to_i
          return nil if end_offset > @data.size

          @data[start_offset...end_offset]
        end

        # Get the head table
        def head : Tables::Head
          @head ||= begin
            data = table_data("head") || raise ParseError.new("Missing required table: head")
            Tables::Head.parse(data)
          end
        end

        # Get the hhea table
        def hhea : Tables::Hhea
          @hhea ||= begin
            data = table_data("hhea") || raise ParseError.new("Missing required table: hhea")
            Tables::Hhea.parse(data)
          end
        end

        # Get the maxp table
        def maxp : Tables::Maxp
          @maxp ||= begin
            data = table_data("maxp") || raise ParseError.new("Missing required table: maxp")
            Tables::Maxp.parse(data)
          end
        end

        # Get the hmtx table
        def hmtx : Tables::Hmtx
          @hmtx ||= begin
            data = table_data("hmtx") || raise ParseError.new("Missing required table: hmtx")
            Tables::Hmtx.parse(data, hhea.number_of_h_metrics, maxp.num_glyphs)
          end
        end

        # Get the cmap table
        def cmap : Tables::Cmap
          @cmap ||= begin
            data = table_data("cmap") || raise ParseError.new("Missing required table: cmap")
            Tables::Cmap.parse(data)
          end
        end

        # Get the loca table
        def loca : Tables::Loca
          @loca ||= begin
            data = table_data("loca") || raise ParseError.new("Missing required table: loca")
            Tables::Loca.parse(data, head.long_offsets?, maxp.num_glyphs)
          end
        end

        # Get the glyf table
        def glyf : Tables::Glyf
          @glyf ||= begin
            data = table_data("glyf") || raise ParseError.new("Missing required table: glyf")
            Tables::Glyf.parse(data)
          end
        end

        # Get the name table
        def name : Tables::Name
          @name ||= begin
            data = table_data("name") || raise ParseError.new("Missing required table: name")
            Tables::Name.parse(data)
          end
        end

        # Get the post table
        def post : Tables::Post
          @post ||= begin
            data = table_data("post") || raise ParseError.new("Missing required table: post")
            Tables::Post.parse(data)
          end
        end

        # Get the OS/2 table
        def os2 : Tables::OS2?
          @os2 ||= begin
            data = table_data("OS/2")
            data ? Tables::OS2.parse(data) : nil
          end
        end

        # Get the PostScript name
        def postscript_name : String
          name.postscript_name || name.full_name || "Unknown"
        end

        # Get the font family name
        def family_name : String
          name.font_family || "Unknown"
        end

        # Get the units per em
        def units_per_em : UInt16
          head.units_per_em
        end

        # Get the ascender (in font units)
        def ascender : Int16
          os2.try(&.ascender) || hhea.ascent
        end

        # Get the descender (in font units)
        def descender : Int16
          os2.try(&.descender) || hhea.descent
        end

        # Get the cap height (in font units)
        def cap_height : Int16
          os2.try(&.cap_height) || (ascender * 0.7).to_i16
        end

        # Get the italic angle
        def italic_angle : Float64
          post.italic_angle
        end

        # Check if the font is bold
        def bold? : Bool
          os2.try(&.bold?) || head.bold?
        end

        # Check if the font is italic
        def italic? : Bool
          os2.try(&.italic?) || head.italic?
        end

        # Check if the font is monospaced
        def monospaced? : Bool
          post.monospaced?
        end

        # Get the glyph ID for a Unicode codepoint
        def glyph_id(codepoint : UInt32) : UInt16
          cmap.glyph_id(codepoint) || 0_u16
        end

        # Get the glyph ID for a character
        def glyph_id(char : Char) : UInt16
          glyph_id(char.ord.to_u32)
        end

        # Get the advance width for a glyph (in font units)
        def advance_width(glyph_id : UInt16) : UInt16
          hmtx.advance_width(glyph_id)
        end

        # Get the advance width for a character (in font units)
        def char_width(char : Char) : UInt16
          advance_width(glyph_id(char))
        end

        # Get the font bounding box
        def bounding_box : Tuple(Int16, Int16, Int16, Int16)
          head.bounding_box
        end

        # Get flags for PDF font descriptor
        def flags : UInt32
          flags = 0_u32

          # Bit 1: FixedPitch
          flags |= (1 << 0) if monospaced?

          # Bit 2: Serif (not easily detected, skip)
          # Bit 3: Symbolic (not easily detected, skip)

          # Bit 4: Script (not easily detected, skip)

          # Bit 6: Italic
          flags |= (1 << 6) if italic?

          # Bit 17: AllCap (not easily detected, skip)
          # Bit 18: SmallCap (not easily detected, skip)
          # Bit 19: ForceBold (not easily detected, skip)

          # If not symbolic, set Nonsymbolic (bit 5)
          flags |= (1 << 5) # Assume nonsymbolic for most fonts

          flags
        end

        # Get the StemV value for PDF (estimate based on weight)
        def stem_v : Int32
          if os2_table = os2
            # Estimate from weight class
            weight = os2_table.weight_class
            if weight <= 400
              68 + (weight / 4)
            else
              68 + (weight / 2)
            end.to_i32
          else
            # Default estimate
            80_i32
          end
        end

        extend IOHelpers
      end
    end
  end
end
