module PDF
  module Fonts
    module TrueType
      module Tables
        # Name IDs defined by the TrueType specification
        module NameID
          COPYRIGHT          =  0_u16
          FONT_FAMILY        =  1_u16
          FONT_SUBFAMILY     =  2_u16
          UNIQUE_ID          =  3_u16
          FULL_NAME          =  4_u16
          VERSION_STRING     =  5_u16
          POSTSCRIPT_NAME    =  6_u16
          TRADEMARK          =  7_u16
          MANUFACTURER       =  8_u16
          DESIGNER           =  9_u16
          DESCRIPTION        = 10_u16
          VENDOR_URL         = 11_u16
          DESIGNER_URL       = 12_u16
          LICENSE            = 13_u16
          LICENSE_URL        = 14_u16
          PREFERRED_FAMILY   = 16_u16
          PREFERRED_SUBFAMILY = 17_u16
          COMPATIBLE_FULL    = 18_u16
          SAMPLE_TEXT        = 19_u16
          POSTSCRIPT_CID     = 20_u16
          WWS_FAMILY         = 21_u16
          WWS_SUBFAMILY      = 22_u16
        end

        # A single name record
        struct NameRecord
          getter platform_id : UInt16
          getter encoding_id : UInt16
          getter language_id : UInt16
          getter name_id : UInt16
          getter length : UInt16
          getter offset : UInt16

          def initialize(
            @platform_id : UInt16,
            @encoding_id : UInt16,
            @language_id : UInt16,
            @name_id : UInt16,
            @length : UInt16,
            @offset : UInt16
          )
          end
        end

        # The 'name' table contains human-readable font names.
        # This table is required for all fonts.
        class Name
          include IOHelpers

          # Table format (0 or 1)
          getter format : UInt16

          # Name records
          getter records : Array(NameRecord)

          # String storage
          getter string_data : Bytes

          def initialize(@format : UInt16, @records : Array(NameRecord), @string_data : Bytes)
          end

          # Parse the name table from raw bytes
          def self.parse(data : Bytes) : Name
            io = IO::Memory.new(data)
            parse(io, data)
          end

          # Parse the name table from an IO
          def self.parse(io : IO, raw_data : Bytes) : Name
            format = read_uint16(io)
            count = read_uint16(io)
            string_offset = read_uint16(io)

            records = Array(NameRecord).new(count.to_i)
            count.times do
              platform_id = read_uint16(io)
              encoding_id = read_uint16(io)
              language_id = read_uint16(io)
              name_id = read_uint16(io)
              length = read_uint16(io)
              offset = read_uint16(io)
              records << NameRecord.new(platform_id, encoding_id, language_id, name_id, length, offset)
            end

            # String data starts at string_offset
            string_data = raw_data[string_offset..]? || Bytes.empty

            new(format, records, string_data)
          end

          # Get a name by ID, preferring English and Unicode/Windows platforms
          def get(name_id : UInt16) : String?
            # Priority: Windows Unicode English > Mac Roman English > Any
            preferred_record = find_preferred_record(name_id)
            return nil unless preferred_record

            extract_string(preferred_record)
          end

          # Get the PostScript name
          def postscript_name : String?
            get(NameID::POSTSCRIPT_NAME)
          end

          # Get the font family name
          def font_family : String?
            get(NameID::PREFERRED_FAMILY) || get(NameID::FONT_FAMILY)
          end

          # Get the full font name
          def full_name : String?
            get(NameID::FULL_NAME)
          end

          # Find the preferred record for a name ID
          private def find_preferred_record(name_id : UInt16) : NameRecord?
            # Collect matching records
            matches = @records.select { |r| r.name_id == name_id }
            return nil if matches.empty?

            # Windows Unicode English (platform 3, encoding 1, language 0x409)
            if r = matches.find { |m| m.platform_id == 3 && m.encoding_id == 1 && m.language_id == 0x0409 }
              return r
            end

            # Windows Unicode any language
            if r = matches.find { |m| m.platform_id == 3 && m.encoding_id == 1 }
              return r
            end

            # Unicode platform
            if r = matches.find { |m| m.platform_id == 0 }
              return r
            end

            # Mac Roman English
            if r = matches.find { |m| m.platform_id == 1 && m.encoding_id == 0 && m.language_id == 0 }
              return r
            end

            # Fall back to first match
            matches.first
          end

          # Extract a string from a name record
          private def extract_string(record : NameRecord) : String?
            return nil if record.offset + record.length > @string_data.size

            data = @string_data[record.offset, record.length]

            # Determine encoding based on platform
            case record.platform_id
            when 0, 3
              # Unicode or Windows: UTF-16BE
              decode_utf16be(data)
            when 1
              # Mac: Assume MacRoman (ASCII-compatible for basic chars)
              String.new(data)
            else
              String.new(data)
            end
          end

          # Decode UTF-16BE to String
          private def decode_utf16be(data : Bytes) : String
            return "" if data.empty?

            chars = [] of Char
            i = 0
            while i + 1 < data.size
              code = (data[i].to_u16 << 8) | data[i + 1].to_u16

              # Handle surrogate pairs
              if code >= 0xD800 && code <= 0xDBFF && i + 3 < data.size
                high = code
                low = (data[i + 2].to_u16 << 8) | data[i + 3].to_u16
                if low >= 0xDC00 && low <= 0xDFFF
                  codepoint = 0x10000 + ((high.to_u32 - 0xD800) << 10) + (low.to_u32 - 0xDC00)
                  chars << codepoint.chr
                  i += 4
                  next
                end
              end

              chars << code.chr
              i += 2
            end

            chars.join
          end

          # Serialize the table to bytes (for subsetting)
          def to_bytes : Bytes
            io = IO::Memory.new
            write(io)
            io.to_slice
          end

          # Write the table to an IO
          def write(io : IO) : Nil
            header_size = 6 + (@records.size * 12)

            write_uint16(io, @format)
            write_uint16(io, @records.size.to_u16)
            write_uint16(io, header_size.to_u16)

            @records.each do |r|
              write_uint16(io, r.platform_id)
              write_uint16(io, r.encoding_id)
              write_uint16(io, r.language_id)
              write_uint16(io, r.name_id)
              write_uint16(io, r.length)
              write_uint16(io, r.offset)
            end

            io.write(@string_data)
          end

          extend IOHelpers
        end
      end
    end
  end
end
