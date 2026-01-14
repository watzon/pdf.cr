module PDF
  module Fonts
    module TrueType
      module Tables
        # The 'loca' table stores offsets to glyph data in the 'glyf' table.
        # This table is required for TrueType outlines.
        class Loca
          include IOHelpers

          # Glyph offsets (one more than number of glyphs)
          getter offsets : Array(UInt32)

          # Whether the table uses long (32-bit) offsets
          getter? long_format : Bool

          def initialize(@offsets : Array(UInt32), @long_format : Bool)
          end

          # Parse the loca table from raw bytes
          # Requires index_to_loc_format from head and num_glyphs from maxp
          def self.parse(data : Bytes, long_format : Bool, num_glyphs : UInt16) : Loca
            io = IO::Memory.new(data)
            parse(io, long_format, num_glyphs)
          end

          # Parse the loca table from an IO
          def self.parse(io : IO, long_format : Bool, num_glyphs : UInt16) : Loca
            # loca has numGlyphs + 1 entries
            count = num_glyphs.to_i + 1
            offsets = Array(UInt32).new(count)

            if long_format
              count.times { offsets << read_uint32(io) }
            else
              # Short format uses 16-bit offsets divided by 2
              count.times { offsets << (read_uint16(io).to_u32 * 2) }
            end

            new(offsets, long_format)
          end

          # Get the offset for a glyph
          def offset(glyph_id : UInt16) : UInt32
            @offsets[glyph_id.to_i]? || 0_u32
          end

          # Get the length of a glyph's data
          def length(glyph_id : UInt16) : UInt32
            start_offset = @offsets[glyph_id.to_i]? || return 0_u32
            end_offset = @offsets[glyph_id.to_i + 1]? || return 0_u32
            end_offset - start_offset
          end

          # Get the offset and length for a glyph
          def glyph_range(glyph_id : UInt16) : Tuple(UInt32, UInt32)
            {offset(glyph_id), length(glyph_id)}
          end

          # Check if a glyph has outline data
          def has_outline?(glyph_id : UInt16) : Bool
            length(glyph_id) > 0
          end

          # Serialize this table to bytes
          def to_bytes : Bytes
            io = IO::Memory.new
            write(io)
            io.to_slice
          end

          # Write this table to an IO
          def write(io : IO) : Nil
            if @long_format
              @offsets.each { |off| write_uint32(io, off) }
            else
              @offsets.each { |off| write_uint16(io, (off // 2).to_u16) }
            end
          end

          # Create a new loca table for a subset of glyphs
          def self.create(glyph_lengths : Array(UInt32), long_format : Bool) : Loca
            offsets = Array(UInt32).new(glyph_lengths.size + 1)
            current_offset = 0_u32

            glyph_lengths.each do |length|
              offsets << current_offset
              current_offset += length
            end
            offsets << current_offset

            new(offsets, long_format)
          end

          extend IOHelpers
        end
      end
    end
  end
end
