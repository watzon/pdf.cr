module PDF
  module Objects
    # Represents a PDF name object.
    #
    # Names are atomic symbols uniquely defined by a sequence of characters.
    # They are introduced by a forward slash (/) followed by the name.
    #
    # Special characters in names must be escaped using a number sign (#)
    # followed by two hexadecimal digits representing the character code.
    #
    # ```
    # name = PDF::Objects::Name.new("Type")
    # name.to_pdf # => "/Type"
    #
    # special = PDF::Objects::Name.new("Name With Spaces")
    # special.to_pdf # => "/Name#20With#20Spaces"
    # ```
    #
    # Note: The slash is part of the syntax, not the name itself.
    class Name < Base
      # Characters that must be escaped in PDF names
      # (whitespace, delimiters, and # itself)
      ESCAPE_CHARS = Set{
        0x00_u8, 0x09_u8, 0x0A_u8, 0x0C_u8, 0x0D_u8, 0x20_u8, # Whitespace
        0x28_u8, 0x29_u8,                                     # ()
        0x3C_u8, 0x3E_u8,                                     # <>
        0x5B_u8, 0x5D_u8,                                     # []
        0x7B_u8, 0x7D_u8,                                     # {}
        0x2F_u8,                                              # /
        0x25_u8,                                              # %
        0x23_u8,                                              # #
      }

      getter value : ::String

      def initialize(@value : ::String)
      end

      def to_pdf : ::String
        ::String.build do |io|
          io << '/'
          @value.each_byte do |byte|
            if byte < 0x21 || byte > 0x7E || ESCAPE_CHARS.includes?(byte)
              # Escape as #XX
              io << '#'
              io << byte.to_s(16, upcase: true).rjust(2, '0')
            else
              io << byte.chr
            end
          end
        end
      end

      def to_s : ::String
        @value
      end

      def_equals_and_hash @value

      # Common PDF names as constants for convenience
      TYPE        = new("Type")
      SUBTYPE     = new("Subtype")
      PAGES       = new("Pages")
      PAGE        = new("Page")
      CATALOG     = new("Catalog")
      COUNT       = new("Count")
      KIDS        = new("Kids")
      PARENT      = new("Parent")
      MEDIABOX    = new("MediaBox")
      RESOURCES   = new("Resources")
      CONTENTS    = new("Contents")
      FONT        = new("Font")
      XOBJECT     = new("XObject")
      EXTGSTATE   = new("ExtGState")
      PROCSET     = new("ProcSet")
      LENGTH      = new("Length")
      FILTER      = new("Filter")
      FLATEDECODE = new("FlateDecode")
      SIZE        = new("Size")
      ROOT        = new("Root")
      INFO        = new("Info")
      ID          = new("ID")
    end
  end
end
