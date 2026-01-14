module PDF
  module Fonts
    module TrueType
      # Represents a table record in the TrueType font directory.
      # Each record describes one table in the font file.
      struct TableRecord
        # 4-byte table identifier
        getter tag : String

        # Checksum for the table
        getter checksum : UInt32

        # Offset from beginning of font file
        getter offset : UInt32

        # Length of the table in bytes
        getter length : UInt32

        def initialize(@tag : String, @checksum : UInt32, @offset : UInt32, @length : UInt32)
        end

        # Parse a table record from the given IO
        def self.parse(io : IO) : TableRecord
          tag = String.new(Bytes.new(4).tap { |b| io.read_fully(b) })
          checksum = read_uint32(io)
          offset = read_uint32(io)
          length = read_uint32(io)
          new(tag, checksum, offset, length)
        end

        # Write this table record to the given IO
        def write(io : IO) : Nil
          io.write(@tag.to_slice)
          write_uint32(io, @checksum)
          write_uint32(io, @offset)
          write_uint32(io, @length)
        end

        private def self.read_uint32(io : IO) : UInt32
          bytes = Bytes.new(4)
          io.read_fully(bytes)
          (bytes[0].to_u32 << 24) | (bytes[1].to_u32 << 16) |
            (bytes[2].to_u32 << 8) | bytes[3].to_u32
        end

        private def write_uint32(io : IO, value : UInt32) : Nil
          io.write_byte((value >> 24).to_u8)
          io.write_byte(((value >> 16) & 0xFF).to_u8)
          io.write_byte(((value >> 8) & 0xFF).to_u8)
          io.write_byte((value & 0xFF).to_u8)
        end
      end
    end
  end
end
