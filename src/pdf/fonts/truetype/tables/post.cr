module PDF
  module Fonts
    module TrueType
      module Tables
        # The 'post' table contains PostScript-related information.
        # This table is required for all fonts.
        class Post
          include IOHelpers

          # Table version (1.0, 2.0, 2.5, or 3.0)
          getter version : Float64

          # Italic angle in degrees (counter-clockwise from vertical)
          getter italic_angle : Float64

          # Suggested underline position (negative = below baseline)
          getter underline_position : Int16

          # Suggested underline thickness
          getter underline_thickness : Int16

          # Is the font monospaced?
          getter is_fixed_pitch : UInt32

          # Minimum memory usage when font is downloaded
          getter min_mem_type42 : UInt32
          getter max_mem_type42 : UInt32

          # Minimum memory usage when font is downloaded as Type 1
          getter min_mem_type1 : UInt32
          getter max_mem_type1 : UInt32

          # Glyph name indices (for version 2.0)
          getter glyph_name_indices : Array(UInt16)?

          # Extra glyph names (for version 2.0)
          getter glyph_names : Array(String)?

          def initialize(
            @version : Float64,
            @italic_angle : Float64,
            @underline_position : Int16,
            @underline_thickness : Int16,
            @is_fixed_pitch : UInt32,
            @min_mem_type42 : UInt32,
            @max_mem_type42 : UInt32,
            @min_mem_type1 : UInt32,
            @max_mem_type1 : UInt32,
            @glyph_name_indices : Array(UInt16)? = nil,
            @glyph_names : Array(String)? = nil
          )
          end

          # Parse the post table from raw bytes
          def self.parse(data : Bytes) : Post
            io = IO::Memory.new(data)
            parse(io, data.size)
          end

          # Parse the post table from an IO
          def self.parse(io : IO, data_size : Int32) : Post
            version = read_fixed(io)
            italic_angle = read_fixed(io)
            underline_position = read_int16(io)
            underline_thickness = read_int16(io)
            is_fixed_pitch = read_uint32(io)
            min_mem_type42 = read_uint32(io)
            max_mem_type42 = read_uint32(io)
            min_mem_type1 = read_uint32(io)
            max_mem_type1 = read_uint32(io)

            glyph_name_indices = nil
            glyph_names = nil

            # Version 2.0 has glyph name data
            if version >= 2.0 && version < 2.5 && io.pos < data_size
              num_glyphs = read_uint16(io)
              glyph_name_indices = Array(UInt16).new(num_glyphs.to_i)
              num_glyphs.times { glyph_name_indices << read_uint16(io) }

              # Read extra glyph names (indices >= 258)
              glyph_names = [] of String
              while io.pos < data_size
                length = read_uint8(io)
                break if length == 0 && io.pos >= data_size
                name_bytes = Bytes.new(length.to_i)
                io.read_fully(name_bytes)
                glyph_names << String.new(name_bytes)
              end
            end

            new(
              version, italic_angle, underline_position, underline_thickness,
              is_fixed_pitch, min_mem_type42, max_mem_type42,
              min_mem_type1, max_mem_type1, glyph_name_indices, glyph_names
            )
          end

          # Is this a monospaced font?
          def monospaced? : Bool
            @is_fixed_pitch != 0
          end

          # Get the glyph name for a glyph ID
          def glyph_name(glyph_id : UInt16) : String?
            return nil if @version < 2.0 || @version >= 2.5

            indices = @glyph_name_indices
            names = @glyph_names
            return nil unless indices && glyph_id < indices.size

            index = indices[glyph_id]

            if index < 258
              # Standard Macintosh glyph name
              STANDARD_NAMES[index]?
            elsif names
              # Extra glyph name
              extra_index = index.to_i - 258
              extra_index >= 0 && extra_index < names.size ? names[extra_index] : nil
            else
              nil
            end
          end

          # Serialize the table to bytes
          def to_bytes : Bytes
            io = IO::Memory.new
            write(io)
            io.to_slice
          end

          # Write the table to an IO
          def write(io : IO) : Nil
            write_int32(io, (@version * 65536).to_i32)
            write_int32(io, (@italic_angle * 65536).to_i32)
            write_int16(io, @underline_position)
            write_int16(io, @underline_thickness)
            write_uint32(io, @is_fixed_pitch)
            write_uint32(io, @min_mem_type42)
            write_uint32(io, @max_mem_type42)
            write_uint32(io, @min_mem_type1)
            write_uint32(io, @max_mem_type1)

            if @version >= 2.0 && @version < 2.5
              indices = @glyph_name_indices
              names = @glyph_names

              if indices
                write_uint16(io, indices.size.to_u16)
                indices.each { |i| write_uint16(io, i) }
              end

              if names
                names.each do |name|
                  io.write_byte(name.bytesize.to_u8)
                  io.write(name.to_slice)
                end
              end
            end
          end

          # Standard Macintosh glyph names (first 258)
          STANDARD_NAMES = [
            ".notdef", ".null", "nonmarkingreturn", "space", "exclam", "quotedbl",
            "numbersign", "dollar", "percent", "ampersand", "quotesingle", "parenleft",
            "parenright", "asterisk", "plus", "comma", "hyphen", "period", "slash",
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
            "nine", "colon", "semicolon", "less", "equal", "greater", "question", "at",
            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
            "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "bracketleft",
            "backslash", "bracketright", "asciicircum", "underscore", "grave", "a", "b",
            "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q",
            "r", "s", "t", "u", "v", "w", "x", "y", "z", "braceleft", "bar", "braceright",
            "asciitilde", "Adieresis", "Aring", "Ccedilla", "Eacute", "Ntilde", "Odieresis",
            "Udieresis", "aacute", "agrave", "acircumflex", "adieresis", "atilde", "aring",
            "ccedilla", "eacute", "egrave", "ecircumflex", "edieresis", "iacute", "igrave",
            "icircumflex", "idieresis", "ntilde", "oacute", "ograve", "ocircumflex",
            "odieresis", "otilde", "uacute", "ugrave", "ucircumflex", "udieresis", "dagger",
            "degree", "cent", "sterling", "section", "bullet", "paragraph", "germandbls",
            "registered", "copyright", "trademark", "acute", "dieresis", "notequal",
            "AE", "Oslash", "infinity", "plusminus", "lessequal", "greaterequal", "yen",
            "mu", "partialdiff", "summation", "product", "pi", "integral", "ordfeminine",
            "ordmasculine", "Omega", "ae", "oslash", "questiondown", "exclamdown", "logicalnot",
            "radical", "florin", "approxequal", "Delta", "guillemotleft", "guillemotright",
            "ellipsis", "nonbreakingspace", "Agrave", "Atilde", "Otilde", "OE", "oe",
            "endash", "emdash", "quotedblleft", "quotedblright", "quoteleft", "quoteright",
            "divide", "lozenge", "ydieresis", "Ydieresis", "fraction", "currency",
            "guilsinglleft", "guilsinglright", "fi", "fl", "daggerdbl", "periodcentered",
            "quotesinglbase", "quotedblbase", "perthousand", "Acircumflex", "Ecircumflex",
            "Aacute", "Edieresis", "Egrave", "Iacute", "Icircumflex", "Idieresis", "Igrave",
            "Oacute", "Ocircumflex", "apple", "Ograve", "Uacute", "Ucircumflex", "Ugrave",
            "dotlessi", "circumflex", "tilde", "macron", "breve", "dotaccent", "ring",
            "cedilla", "hungarumlaut", "ogonek", "caron", "Lslash", "lslash", "Scaron",
            "scaron", "Zcaron", "zcaron", "brokenbar", "Eth", "eth", "Yacute", "yacute",
            "Thorn", "thorn", "minus", "multiply", "onesuperior", "twosuperior",
            "threesuperior", "onehalf", "onequarter", "threequarters", "franc", "Gbreve",
            "gbreve", "Idotaccent", "Scedilla", "scedilla", "Cacute", "cacute", "Ccaron",
            "ccaron", "dcroat",
          ]

          extend IOHelpers
        end
      end
    end
  end
end
