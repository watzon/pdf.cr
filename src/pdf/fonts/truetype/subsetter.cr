module PDF
  module Fonts
    module TrueType
      # Font subsetter that creates a new font containing only the glyphs
      # needed for a specific set of characters.
      class Subsetter
        include IOHelpers

        # The original font parser
        getter parser : Parser

        # Characters to include in the subset
        @characters : Set(Char)

        # Glyph IDs to include (calculated from characters)
        @glyph_ids : Set(UInt16)

        # Mapping from old glyph IDs to new glyph IDs
        @glyph_id_map : Hash(UInt16, UInt16)

        def initialize(@parser : Parser)
          @characters = Set(Char).new
          @glyph_ids = Set(UInt16).new
          @glyph_id_map = Hash(UInt16, UInt16).new
        end

        # Add a character to the subset
        def use(char : Char) : Nil
          @characters << char
        end

        # Add a string of characters to the subset
        def use(text : String) : Nil
          text.each_char { |c| use(c) }
        end

        # Get the new glyph ID for an old glyph ID
        def new_glyph_id(old_id : UInt16) : UInt16
          @glyph_id_map[old_id]? || 0_u16
        end

        # Get the Unicode to new glyph ID mapping
        def unicode_to_glyph_map : Hash(UInt32, UInt16)
          result = Hash(UInt32, UInt16).new
          @characters.each do |char|
            old_glyph_id = @parser.glyph_id(char)
            if new_id = @glyph_id_map[old_glyph_id]?
              result[char.ord.to_u32] = new_id
            end
          end
          result
        end

        # Build the subset font
        def subset : Bytes
          # Collect glyph IDs for all characters
          collect_glyph_ids

          # Build glyph ID map
          build_glyph_id_map

          # Build the subset font
          build_font
        end

        private def collect_glyph_ids : Nil
          @glyph_ids.clear

          # Always include glyph 0 (.notdef)
          @glyph_ids << 0_u16

          # Add glyphs for each character
          @characters.each do |char|
            glyph_id = @parser.glyph_id(char)
            @glyph_ids << glyph_id if glyph_id > 0
          end

          # Add component glyphs for composite glyphs
          if @parser.truetype?
            original_ids = @glyph_ids.dup
            original_ids.each do |glyph_id|
              components = @parser.glyf.component_glyph_ids(glyph_id, @parser.loca)
              components.each { |c| @glyph_ids << c }
            end
          end
        end

        private def build_glyph_id_map : Nil
          @glyph_id_map.clear

          # Sort glyph IDs and assign new sequential IDs
          sorted_ids = @glyph_ids.to_a.sort
          sorted_ids.each_with_index do |old_id, new_id|
            @glyph_id_map[old_id] = new_id.to_u16
          end
        end

        private def build_font : Bytes
          io = IO::Memory.new

          # Calculate tables to include and their data
          tables = build_tables

          # Calculate offsets
          num_tables = tables.size
          header_size = 12 + (num_tables * 16)

          # Align to 4-byte boundary
          table_start = ((header_size + 3) // 4) * 4

          # Calculate table offsets
          table_offsets = [] of UInt32
          current_offset = table_start.to_u32
          tables.each do |_, data|
            table_offsets << current_offset
            # Tables are padded to 4-byte boundaries
            padded_length = ((data.size + 3) // 4) * 4
            current_offset += padded_length.to_u32
          end

          # Write header
          write_uint32(io, @parser.sfnt_version)
          write_uint16(io, num_tables.to_u16)

          search_range = (2 ** Math.log2(num_tables).floor.to_i) * 16
          entry_selector = Math.log2(search_range / 16).floor.to_i
          range_shift = (num_tables * 16) - search_range

          write_uint16(io, search_range.to_u16)
          write_uint16(io, entry_selector.to_u16)
          write_uint16(io, range_shift.to_u16)

          # Write table records
          tables.each_with_index do |(tag, data), i|
            io.write(tag.to_slice)
            write_uint32(io, calculate_checksum(data))
            write_uint32(io, table_offsets[i])
            write_uint32(io, data.size.to_u32)
          end

          # Pad to table start
          while io.pos < table_start
            io.write_byte(0_u8)
          end

          # Write tables
          tables.each do |_, data|
            io.write(data)
            # Pad to 4-byte boundary
            padding = (4 - (data.size % 4)) % 4
            padding.times { io.write_byte(0_u8) }
          end

          # Calculate and update head checksum adjustment
          result = io.to_slice
          update_head_checksum(result)

          result
        end

        private def build_tables : Array(Tuple(String, Bytes))
          tables = [] of Tuple(String, Bytes)

          # Required tables in recommended order
          tables << {"cmap", build_cmap}
          tables << {"glyf", build_glyf.first.to_bytes} if @parser.truetype?
          tables << {"head", build_head}
          tables << {"hhea", build_hhea}
          tables << {"hmtx", build_hmtx}
          tables << {"loca", build_loca} if @parser.truetype?
          tables << {"maxp", build_maxp}
          tables << {"name", @parser.name.to_bytes}
          tables << {"post", build_post}

          if @parser.has_table?("OS/2")
            tables << {"OS/2", @parser.os2.not_nil!.to_bytes}
          end

          # Sort tables by tag (required for proper checksums)
          tables.sort_by! { |tag, _| tag }
          tables
        end

        private def build_cmap : Bytes
          # Build new Unicode to glyph mapping
          mapping = unicode_to_glyph_map
          Tables::Cmap.encode(mapping)
        end

        private def build_glyf : Tuple(Tables::Glyf, Tables::Loca)
          sorted_ids = @glyph_id_map.keys.sort_by { |id| @glyph_id_map[id] }
          @parser.glyf.subset(sorted_ids, @parser.loca, @glyph_id_map)
        end

        @subset_loca : Tables::Loca?

        private def build_loca : Bytes
          _, loca = build_glyf
          @subset_loca = loca
          loca.to_bytes
        end

        private def build_head : Bytes
          head = @parser.head
          loca = @subset_loca || build_glyf.last

          # Create new head with updated loca format
          new_head = Tables::Head.new(
            head.major_version,
            head.minor_version,
            head.font_revision,
            0_u32, # checksum_adjustment will be updated later
            head.magic_number,
            head.flags,
            head.units_per_em,
            head.created,
            head.modified,
            head.x_min,
            head.y_min,
            head.x_max,
            head.y_max,
            head.mac_style,
            head.lowest_rec_ppem,
            head.font_direction_hint,
            loca.long_format? ? 1_i16 : 0_i16,
            head.glyph_data_format
          )
          new_head.to_bytes
        end

        private def build_hhea : Bytes
          hhea = @parser.hhea
          new_hhea = Tables::Hhea.new(
            hhea.major_version,
            hhea.minor_version,
            hhea.ascent,
            hhea.descent,
            hhea.line_gap,
            hhea.advance_width_max,
            hhea.min_left_side_bearing,
            hhea.min_right_side_bearing,
            hhea.x_max_extent,
            hhea.caret_slope_rise,
            hhea.caret_slope_run,
            hhea.caret_offset,
            0_i16, 0_i16, 0_i16, 0_i16, # reserved
            hhea.metric_data_format,
            @glyph_id_map.size.to_u16 # All glyphs have full metrics
          )
          new_hhea.to_bytes
        end

        private def build_hmtx : Bytes
          @parser.hmtx.subset(@glyph_id_map).to_bytes
        end

        private def build_maxp : Bytes
          maxp = @parser.maxp
          io = IO::Memory.new

          write_uint32(io, maxp.version)
          write_uint16(io, @glyph_id_map.size.to_u16)

          if maxp.truetype?
            write_uint16(io, maxp.max_points || 0_u16)
            write_uint16(io, maxp.max_contours || 0_u16)
            write_uint16(io, maxp.max_composite_points || 0_u16)
            write_uint16(io, maxp.max_composite_contours || 0_u16)
            write_uint16(io, maxp.max_zones || 2_u16)
            write_uint16(io, maxp.max_twilight_points || 0_u16)
            write_uint16(io, maxp.max_storage || 0_u16)
            write_uint16(io, maxp.max_function_defs || 0_u16)
            write_uint16(io, maxp.max_instruction_defs || 0_u16)
            write_uint16(io, maxp.max_stack_elements || 0_u16)
            write_uint16(io, maxp.max_size_of_instructions || 0_u16)
            write_uint16(io, maxp.max_component_elements || 0_u16)
            write_uint16(io, maxp.max_component_depth || 0_u16)
          end

          io.to_slice
        end

        private def build_post : Bytes
          post = @parser.post

          # Use version 3.0 (no glyph names) for smaller size
          io = IO::Memory.new
          write_int32(io, 0x00030000) # version 3.0
          write_int32(io, (post.italic_angle * 65536).to_i32)
          write_int16(io, post.underline_position)
          write_int16(io, post.underline_thickness)
          write_uint32(io, post.is_fixed_pitch)
          write_uint32(io, post.min_mem_type42)
          write_uint32(io, post.max_mem_type42)
          write_uint32(io, post.min_mem_type1)
          write_uint32(io, post.max_mem_type1)

          io.to_slice
        end

        private def calculate_checksum(data : Bytes) : UInt32
          sum = 0_u32
          i = 0
          while i < data.size
            value = 0_u32
            4.times do |j|
              value <<= 8
              value |= (data[i + j]? || 0_u8).to_u32
            end
            sum &+= value
            i += 4
          end
          sum
        end

        private def update_head_checksum(data : Bytes) : Nil
          # Find head table offset
          io = IO::Memory.new(data)
          io.skip(4) # sfnt version
          num_tables = read_uint16(io)
          io.skip(6) # search params

          head_offset = 0_u32
          num_tables.times do
            tag = String.new(read_bytes(io, 4))
            io.skip(4) # checksum
            offset = read_uint32(io)
            io.skip(4) # length

            if tag == "head"
              head_offset = offset
              break
            end
          end

          return if head_offset == 0

          # Calculate checksum adjustment
          full_checksum = calculate_checksum(data)
          adjustment = 0xB1B0AFBA_u32 &- full_checksum

          # Write adjustment at head offset + 8
          adjustment_offset = head_offset + 8
          data[adjustment_offset] = ((adjustment >> 24) & 0xFF).to_u8
          data[adjustment_offset + 1] = ((adjustment >> 16) & 0xFF).to_u8
          data[adjustment_offset + 2] = ((adjustment >> 8) & 0xFF).to_u8
          data[adjustment_offset + 3] = (adjustment & 0xFF).to_u8
        end

        extend IOHelpers
      end
    end
  end
end
