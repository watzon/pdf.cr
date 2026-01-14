module PDF
  module Objects
    # Represents a PDF string object.
    #
    # PDF strings can be written in two forms:
    # - Literal strings: enclosed in parentheses `(Hello)`
    # - Hexadecimal strings: enclosed in angle brackets `<48656C6C6F>`
    #
    # Literal strings can contain:
    # - Balanced parentheses without escaping
    # - Escape sequences: `\n`, `\r`, `\t`, `\b`, `\f`, `\\`, `\(`, `\)`
    # - Octal character codes: `\ddd`
    #
    # For Unicode text, PDF uses UTF-16BE with a BOM (byte order mark).
    #
    # ```
    # str = PDF::Objects::Str.new("Hello, World!")
    # str.to_pdf # => "(Hello, World!)"
    #
    # hex = PDF::Objects::Str.new("Hello", hex: true)
    # hex.to_pdf # => "<48656C6C6F>"
    # ```
    class Str < Base
      # UTF-16BE Byte Order Mark
      BOM = "\xFE\xFF"

      getter value : ::String
      getter? hex : Bool

      def initialize(@value : ::String, @hex : Bool = false)
      end

      def to_pdf : ::String
        if @hex
          to_hex_string
        else
          to_literal_string
        end
      end

      # Creates a string with Unicode content (uses UTF-16BE with BOM)
      def self.unicode(text : ::String) : Str
        # Check if text contains non-ASCII characters
        needs_unicode = text.each_char.any? { |c| c.ord > 127 }

        if needs_unicode
          # Encode as UTF-16BE with BOM
          utf16_bytes = ::String.build do |io|
            io << BOM
            text.each_char do |char|
              code = char.ord
              if code <= 0xFFFF
                # BMP character
                io.write_byte((code >> 8).to_u8)
                io.write_byte((code & 0xFF).to_u8)
              else
                # Supplementary character - use surrogate pair
                code -= 0x10000
                high_surrogate = 0xD800 + (code >> 10)
                low_surrogate = 0xDC00 + (code & 0x3FF)
                io.write_byte((high_surrogate >> 8).to_u8)
                io.write_byte((high_surrogate & 0xFF).to_u8)
                io.write_byte((low_surrogate >> 8).to_u8)
                io.write_byte((low_surrogate & 0xFF).to_u8)
              end
            end
          end
          new(utf16_bytes, hex: true)
        else
          new(text)
        end
      end

      def_equals_and_hash @value, @hex

      private def to_literal_string : ::String
        ::String.build do |io|
          io << '('
          @value.each_byte do |byte|
            case byte
            when 0x0A # \n
              io << "\\n"
            when 0x0D # \r
              io << "\\r"
            when 0x09 # \t
              io << "\\t"
            when 0x08 # \b
              io << "\\b"
            when 0x0C # \f
              io << "\\f"
            when 0x28 # (
              io << "\\("
            when 0x29 # )
              io << "\\)"
            when 0x5C # \
              io << "\\\\"
            else
              if byte < 0x20 || byte > 0x7E
                # Use octal escape for non-printable characters
                io << '\\'
                io << byte.to_s(8).rjust(3, '0')
              else
                io << byte.chr
              end
            end
          end
          io << ')'
        end
      end

      private def to_hex_string : ::String
        ::String.build do |io|
          io << '<'
          @value.each_byte do |byte|
            io << byte.to_s(16, upcase: true).rjust(2, '0')
          end
          io << '>'
        end
      end
    end
  end
end
