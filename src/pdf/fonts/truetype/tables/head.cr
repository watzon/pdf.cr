module PDF
  module Fonts
    module TrueType
      module Tables
        # The 'head' table contains global information about the font.
        # This is a required table.
        class Head
          include IOHelpers

          # Major version (should be 1)
          getter major_version : UInt16

          # Minor version (should be 0)
          getter minor_version : UInt16

          # Font revision (set by font manufacturer)
          getter font_revision : Float64

          # Checksum adjustment
          getter checksum_adjustment : UInt32

          # Magic number (should be 0x5F0F3CF5)
          getter magic_number : UInt32

          # Flags
          getter flags : UInt16

          # Units per em (typically 1000 or 2048)
          getter units_per_em : UInt16

          # Created timestamp
          getter created : Int64

          # Modified timestamp
          getter modified : Int64

          # Bounding box for all glyphs (xMin)
          getter x_min : Int16

          # Bounding box for all glyphs (yMin)
          getter y_min : Int16

          # Bounding box for all glyphs (xMax)
          getter x_max : Int16

          # Bounding box for all glyphs (yMax)
          getter y_max : Int16

          # Mac style flags
          getter mac_style : UInt16

          # Smallest readable size in pixels
          getter lowest_rec_ppem : UInt16

          # Font direction hint (deprecated, should be 2)
          getter font_direction_hint : Int16

          # Loca table format: 0 = short offsets, 1 = long offsets
          getter index_to_loc_format : Int16

          # Glyph data format (should be 0)
          getter glyph_data_format : Int16

          def initialize(
            @major_version : UInt16,
            @minor_version : UInt16,
            @font_revision : Float64,
            @checksum_adjustment : UInt32,
            @magic_number : UInt32,
            @flags : UInt16,
            @units_per_em : UInt16,
            @created : Int64,
            @modified : Int64,
            @x_min : Int16,
            @y_min : Int16,
            @x_max : Int16,
            @y_max : Int16,
            @mac_style : UInt16,
            @lowest_rec_ppem : UInt16,
            @font_direction_hint : Int16,
            @index_to_loc_format : Int16,
            @glyph_data_format : Int16
          )
          end

          # Parse the head table from raw bytes
          def self.parse(data : Bytes) : Head
            io = IO::Memory.new(data)
            parse(io)
          end

          # Parse the head table from an IO
          def self.parse(io : IO) : Head
            major_version = read_uint16(io)
            minor_version = read_uint16(io)
            font_revision = read_fixed(io)
            checksum_adjustment = read_uint32(io)
            magic_number = read_uint32(io)
            flags = read_uint16(io)
            units_per_em = read_uint16(io)
            created = read_int64(io)
            modified = read_int64(io)
            x_min = read_int16(io)
            y_min = read_int16(io)
            x_max = read_int16(io)
            y_max = read_int16(io)
            mac_style = read_uint16(io)
            lowest_rec_ppem = read_uint16(io)
            font_direction_hint = read_int16(io)
            index_to_loc_format = read_int16(io)
            glyph_data_format = read_int16(io)

            new(
              major_version, minor_version, font_revision, checksum_adjustment,
              magic_number, flags, units_per_em, created, modified,
              x_min, y_min, x_max, y_max, mac_style, lowest_rec_ppem,
              font_direction_hint, index_to_loc_format, glyph_data_format
            )
          end

          # Serialize this table to bytes
          def to_bytes : Bytes
            io = IO::Memory.new
            write(io)
            io.to_slice
          end

          # Write this table to an IO
          def write(io : IO) : Nil
            write_uint16(io, @major_version)
            write_uint16(io, @minor_version)
            write_int32(io, (@font_revision * 65536).to_i32)
            write_uint32(io, @checksum_adjustment)
            write_uint32(io, @magic_number)
            write_uint16(io, @flags)
            write_uint16(io, @units_per_em)
            write_int64(io, @created)
            write_int64(io, @modified)
            write_int16(io, @x_min)
            write_int16(io, @y_min)
            write_int16(io, @x_max)
            write_int16(io, @y_max)
            write_uint16(io, @mac_style)
            write_uint16(io, @lowest_rec_ppem)
            write_int16(io, @font_direction_hint)
            write_int16(io, @index_to_loc_format)
            write_int16(io, @glyph_data_format)
          end

          private def write_int64(io : IO, value : Int64) : Nil
            write_uint32(io, (value >> 32).to_u32!)
            write_uint32(io, (value & 0xFFFFFFFF).to_u32!)
          end

          # Check if the font is bold
          def bold? : Bool
            (@mac_style & 0x01) != 0
          end

          # Check if the font is italic
          def italic? : Bool
            (@mac_style & 0x02) != 0
          end

          # Check if the loca table uses long offsets
          def long_offsets? : Bool
            @index_to_loc_format == 1
          end

          # Font bounding box as a tuple
          def bounding_box : Tuple(Int16, Int16, Int16, Int16)
            {@x_min, @y_min, @x_max, @y_max}
          end

          extend IOHelpers
        end
      end
    end
  end
end
