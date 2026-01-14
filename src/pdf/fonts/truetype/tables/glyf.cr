module PDF
  module Fonts
    module TrueType
      module Tables
        # Component flags for composite glyphs
        module GlyphFlags
          ARG_1_AND_2_ARE_WORDS    = 0x0001_u16
          ARGS_ARE_XY_VALUES       = 0x0002_u16
          ROUND_XY_TO_GRID         = 0x0004_u16
          WE_HAVE_A_SCALE          = 0x0008_u16
          MORE_COMPONENTS          = 0x0020_u16
          WE_HAVE_AN_X_AND_Y_SCALE = 0x0040_u16
          WE_HAVE_A_TWO_BY_TWO     = 0x0080_u16
          WE_HAVE_INSTRUCTIONS     = 0x0100_u16
          USE_MY_METRICS           = 0x0200_u16
          OVERLAP_COMPOUND         = 0x0400_u16
        end

        # Represents a single glyph's data
        class GlyphData
          include IOHelpers

          # Number of contours (-1 for composite glyphs)
          getter number_of_contours : Int16

          # Bounding box
          getter x_min : Int16
          getter y_min : Int16
          getter x_max : Int16
          getter y_max : Int16

          # Raw glyph data (after header)
          getter raw_data : Bytes

          # Component glyph IDs (for composite glyphs)
          getter component_glyph_ids : Array(UInt16)

          def initialize(
            @number_of_contours : Int16,
            @x_min : Int16,
            @y_min : Int16,
            @x_max : Int16,
            @y_max : Int16,
            @raw_data : Bytes,
            @component_glyph_ids : Array(UInt16) = [] of UInt16
          )
          end

          # Check if this is a composite glyph
          def composite? : Bool
            @number_of_contours < 0
          end

          # Check if this is an empty glyph (no outline)
          def empty? : Bool
            @raw_data.empty? && @number_of_contours == 0
          end

          # Parse a glyph from raw bytes
          def self.parse(data : Bytes) : GlyphData
            return GlyphData.new(0_i16, 0_i16, 0_i16, 0_i16, 0_i16, Bytes.empty) if data.empty?

            io = IO::Memory.new(data)
            parse(io, data)
          end

          # Parse a glyph from an IO
          def self.parse(io : IO, full_data : Bytes) : GlyphData
            number_of_contours = read_int16(io)
            x_min = read_int16(io)
            y_min = read_int16(io)
            x_max = read_int16(io)
            y_max = read_int16(io)

            # The rest is raw glyph data
            header_size = 10
            raw_data = full_data.size > header_size ? full_data[header_size..] : Bytes.empty

            # Extract component glyph IDs for composite glyphs
            component_ids = [] of UInt16
            if number_of_contours < 0 && !raw_data.empty?
              component_ids = extract_component_ids(raw_data)
            end

            new(number_of_contours, x_min, y_min, x_max, y_max, raw_data, component_ids)
          end

          # Extract component glyph IDs from composite glyph data
          private def self.extract_component_ids(data : Bytes) : Array(UInt16)
            ids = [] of UInt16
            io = IO::Memory.new(data)

            loop do
              break if io.pos + 4 > data.size

              flags = read_uint16(io)
              glyph_id = read_uint16(io)
              ids << glyph_id

              # Skip arguments
              if (flags & GlyphFlags::ARG_1_AND_2_ARE_WORDS) != 0
                io.skip(4)
              else
                io.skip(2)
              end

              # Skip transformation
              if (flags & GlyphFlags::WE_HAVE_A_SCALE) != 0
                io.skip(2)
              elsif (flags & GlyphFlags::WE_HAVE_AN_X_AND_Y_SCALE) != 0
                io.skip(4)
              elsif (flags & GlyphFlags::WE_HAVE_A_TWO_BY_TWO) != 0
                io.skip(8)
              end

              break unless (flags & GlyphFlags::MORE_COMPONENTS) != 0
            end

            ids
          rescue
            [] of UInt16
          end

          # Serialize this glyph to bytes
          def to_bytes : Bytes
            return Bytes.empty if empty?

            io = IO::Memory.new
            write(io)
            io.to_slice
          end

          # Write this glyph to an IO
          def write(io : IO) : Nil
            return if empty?

            write_int16(io, @number_of_contours)
            write_int16(io, @x_min)
            write_int16(io, @y_min)
            write_int16(io, @x_max)
            write_int16(io, @y_max)
            io.write(@raw_data)
          end

          extend IOHelpers
        end

        # The 'glyf' table contains glyph outline data.
        # This table is required for TrueType outlines.
        class Glyf
          include IOHelpers

          # Raw table data
          getter raw_data : Bytes

          # Parsed glyphs (lazy loaded)
          @glyphs : Hash(UInt16, GlyphData)

          def initialize(@raw_data : Bytes)
            @glyphs = Hash(UInt16, GlyphData).new
          end

          # Parse the glyf table from raw bytes
          def self.parse(data : Bytes) : Glyf
            new(data)
          end

          # Get glyph data by ID using the loca table
          def glyph(glyph_id : UInt16, loca : Loca) : GlyphData
            @glyphs[glyph_id] ||= begin
              offset, length = loca.glyph_range(glyph_id)
              if length > 0 && offset + length <= @raw_data.size
                GlyphData.parse(@raw_data[offset, length])
              else
                GlyphData.new(0_i16, 0_i16, 0_i16, 0_i16, 0_i16, Bytes.empty)
              end
            end
          end

          # Get all component glyph IDs for a glyph (recursive)
          def component_glyph_ids(glyph_id : UInt16, loca : Loca) : Set(UInt16)
            result = Set(UInt16).new
            collect_components(glyph_id, loca, result)
            result
          end

          private def collect_components(glyph_id : UInt16, loca : Loca, result : Set(UInt16)) : Nil
            return if result.includes?(glyph_id)

            glyph_data = glyph(glyph_id, loca)
            return unless glyph_data.composite?

            glyph_data.component_glyph_ids.each do |component_id|
              result << component_id
              collect_components(component_id, loca, result)
            end
          end

          # Create a subset glyf table with only the specified glyphs
          def subset(glyph_ids : Array(UInt16), loca : Loca, glyph_id_map : Hash(UInt16, UInt16)) : Tuple(Glyf, Loca)
            glyph_data_list = [] of Bytes
            new_offsets = [] of UInt32
            current_offset = 0_u32

            # Sort by new glyph ID to ensure correct order
            sorted_ids = glyph_ids.sort_by { |id| glyph_id_map[id]? || 0_u16 }

            sorted_ids.each do |old_id|
              glyph = glyph(old_id, loca)
              data = glyph.to_bytes

              # For composite glyphs, we need to remap component IDs
              if glyph.composite? && !data.empty?
                data = remap_composite_glyph(data, glyph_id_map)
              end

              # Align to 2-byte boundary
              padding = data.size.odd? ? 1 : 0
              padded_size = data.size + padding

              new_offsets << current_offset
              glyph_data_list << data
              current_offset += padded_size.to_u32
            end
            new_offsets << current_offset

            # Build new glyf data
            new_glyf_io = IO::Memory.new
            glyph_data_list.each do |data|
              new_glyf_io.write(data)
              new_glyf_io.write_byte(0_u8) if data.size.odd? # Padding
            end

            new_glyf = Glyf.new(new_glyf_io.to_slice)

            # Determine if we need long offsets
            long_format = current_offset > 0xFFFF * 2

            new_loca = Loca.new(new_offsets, long_format)

            {new_glyf, new_loca}
          end

          # Remap component glyph IDs in a composite glyph
          private def remap_composite_glyph(data : Bytes, glyph_id_map : Hash(UInt16, UInt16)) : Bytes
            io = IO::Memory.new(data)
            output = IO::Memory.new

            loop do
              break if io.pos + 4 > data.size

              flags_pos = io.pos
              flags = read_uint16(io)
              old_glyph_id = read_uint16(io)

              # Write flags
              write_uint16(output, flags)

              # Write remapped glyph ID
              new_glyph_id = glyph_id_map[old_glyph_id]? || old_glyph_id
              write_uint16(output, new_glyph_id)

              # Copy arguments
              arg_size = (flags & GlyphFlags::ARG_1_AND_2_ARE_WORDS) != 0 ? 4 : 2
              output.write(read_bytes(io, arg_size))

              # Copy transformation
              if (flags & GlyphFlags::WE_HAVE_A_SCALE) != 0
                output.write(read_bytes(io, 2))
              elsif (flags & GlyphFlags::WE_HAVE_AN_X_AND_Y_SCALE) != 0
                output.write(read_bytes(io, 4))
              elsif (flags & GlyphFlags::WE_HAVE_A_TWO_BY_TWO) != 0
                output.write(read_bytes(io, 8))
              end

              break unless (flags & GlyphFlags::MORE_COMPONENTS) != 0
            end

            # Copy any remaining data (instructions)
            remaining = data.size - io.pos
            output.write(read_bytes(io, remaining)) if remaining > 0

            output.to_slice
          end

          # Serialize the table to bytes
          def to_bytes : Bytes
            @raw_data
          end

          extend IOHelpers
        end
      end
    end
  end
end
