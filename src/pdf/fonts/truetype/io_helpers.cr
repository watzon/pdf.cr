module PDF
  module Fonts
    module TrueType
      # Binary I/O helpers for reading TrueType font data.
      # TrueType uses big-endian byte order for all values.
      module IOHelpers
        # Read an unsigned 8-bit integer
        def read_uint8(io : IO) : UInt8
          io.read_byte.not_nil!
        end

        # Read a signed 8-bit integer
        def read_int8(io : IO) : Int8
          read_uint8(io).to_i8!
        end

        # Read an unsigned 16-bit integer (big-endian)
        def read_uint16(io : IO) : UInt16
          bytes = Bytes.new(2)
          io.read_fully(bytes)
          (bytes[0].to_u16 << 8) | bytes[1].to_u16
        end

        # Read a signed 16-bit integer (big-endian)
        def read_int16(io : IO) : Int16
          read_uint16(io).to_i16!
        end

        # Read an unsigned 32-bit integer (big-endian)
        def read_uint32(io : IO) : UInt32
          bytes = Bytes.new(4)
          io.read_fully(bytes)
          (bytes[0].to_u32 << 24) | (bytes[1].to_u32 << 16) |
            (bytes[2].to_u32 << 8) | bytes[3].to_u32
        end

        # Read a signed 32-bit integer (big-endian)
        def read_int32(io : IO) : Int32
          read_uint32(io).to_i32!
        end

        # Read an unsigned 64-bit integer (big-endian)
        def read_uint64(io : IO) : UInt64
          hi = read_uint32(io).to_u64
          lo = read_uint32(io).to_u64
          (hi << 32) | lo
        end

        # Read a signed 64-bit integer (big-endian)
        def read_int64(io : IO) : Int64
          read_uint64(io).to_i64!
        end

        # Read a 16.16 fixed-point number
        def read_fixed(io : IO) : Float64
          value = read_int32(io)
          value.to_f64 / 65536.0
        end

        # Read a 2.14 fixed-point number (F2Dot14)
        def read_f2dot14(io : IO) : Float64
          value = read_int16(io)
          value.to_f64 / 16384.0
        end

        # Read a 4-character tag
        def read_tag(io : IO) : String
          bytes = Bytes.new(4)
          io.read_fully(bytes)
          String.new(bytes)
        end

        # Read a specific number of bytes
        def read_bytes(io : IO, count : Int32) : Bytes
          bytes = Bytes.new(count)
          io.read_fully(bytes)
          bytes
        end

        # Skip bytes
        def skip_bytes(io : IO, count : Int32) : Nil
          io.skip(count)
        end

        # Write an unsigned 16-bit integer (big-endian)
        def write_uint16(io : IO, value : UInt16) : Nil
          io.write_byte((value >> 8).to_u8)
          io.write_byte((value & 0xFF).to_u8)
        end

        # Write a signed 16-bit integer (big-endian)
        def write_int16(io : IO, value : Int16) : Nil
          write_uint16(io, value.to_u16!)
        end

        # Write an unsigned 32-bit integer (big-endian)
        def write_uint32(io : IO, value : UInt32) : Nil
          io.write_byte((value >> 24).to_u8)
          io.write_byte(((value >> 16) & 0xFF).to_u8)
          io.write_byte(((value >> 8) & 0xFF).to_u8)
          io.write_byte((value & 0xFF).to_u8)
        end

        # Write a signed 32-bit integer (big-endian)
        def write_int32(io : IO, value : Int32) : Nil
          write_uint32(io, value.to_u32!)
        end

        # Write a 4-character tag
        def write_tag(io : IO, tag : String) : Nil
          raise ArgumentError.new("Tag must be exactly 4 characters") unless tag.bytesize == 4
          io.write(tag.to_slice)
        end
      end
    end
  end
end
