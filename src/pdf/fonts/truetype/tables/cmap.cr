module PDF
  module Fonts
    module TrueType
      module Tables
        # Encoding record within the cmap table
        struct EncodingRecord
          # Platform ID
          getter platform_id : UInt16

          # Platform-specific encoding ID
          getter encoding_id : UInt16

          # Offset to subtable
          getter offset : UInt32

          def initialize(@platform_id : UInt16, @encoding_id : UInt16, @offset : UInt32)
          end

          # Check if this is a Unicode encoding
          def unicode? : Bool
            # Platform 0 = Unicode
            # Platform 3, encoding 1 = Windows Unicode BMP
            # Platform 3, encoding 10 = Windows Unicode UCS-4
            @platform_id == 0 ||
              (@platform_id == 3 && (@encoding_id == 1 || @encoding_id == 10))
          end
        end

        # The 'cmap' table maps character codes to glyph indices.
        # This table is required for all fonts.
        class Cmap
          include IOHelpers

          # Version (should be 0)
          getter version : UInt16

          # Encoding records
          getter encoding_records : Array(EncodingRecord)

          # Parsed subtables (format -> character to glyph mapping)
          getter subtables : Hash(UInt32, Hash(UInt32, UInt16))

          # Best Unicode subtable offset (for quick access)
          @unicode_subtable_offset : UInt32?

          def initialize(
            @version : UInt16,
            @encoding_records : Array(EncodingRecord),
            @subtables : Hash(UInt32, Hash(UInt32, UInt16)),
          )
            @unicode_subtable_offset = find_best_unicode_subtable
          end

          # Parse the cmap table from raw bytes
          def self.parse(data : Bytes) : Cmap
            io = IO::Memory.new(data)
            parse(io, data)
          end

          # Parse the cmap table from an IO
          def self.parse(io : IO, raw_data : Bytes) : Cmap
            version = read_uint16(io)
            num_tables = read_uint16(io)

            encoding_records = Array(EncodingRecord).new(num_tables.to_i)
            num_tables.times do
              platform_id = read_uint16(io)
              encoding_id = read_uint16(io)
              offset = read_uint32(io)
              encoding_records << EncodingRecord.new(platform_id, encoding_id, offset)
            end

            # Parse subtables
            subtables = Hash(UInt32, Hash(UInt32, UInt16)).new

            encoding_records.each do |record|
              next if subtables.has_key?(record.offset)

              subtable_io = IO::Memory.new(raw_data[record.offset..])
              mapping = parse_subtable(subtable_io, raw_data, record.offset)
              subtables[record.offset] = mapping if mapping
            end

            new(version, encoding_records, subtables)
          end

          # Parse a cmap subtable based on its format
          private def self.parse_subtable(io : IO, raw_data : Bytes, offset : UInt32) : Hash(UInt32, UInt16)?
            format = read_uint16(io)

            case format
            when 0
              parse_format0(io)
            when 4
              parse_format4(io, raw_data, offset)
            when 6
              parse_format6(io)
            when 12
              parse_format12(io)
            else
              # Unsupported format, skip
              nil
            end
          end

          # Format 0: Byte encoding table
          private def self.parse_format0(io : IO) : Hash(UInt32, UInt16)
            _length = read_uint16(io)
            _language = read_uint16(io)

            mapping = Hash(UInt32, UInt16).new
            256.times do |i|
              glyph_id = read_uint8(io)
              mapping[i.to_u32] = glyph_id.to_u16 if glyph_id != 0
            end
            mapping
          end

          # Format 4: Segment mapping to delta values (BMP Unicode)
          private def self.parse_format4(io : IO, raw_data : Bytes, table_offset : UInt32) : Hash(UInt32, UInt16)
            length = read_uint16(io)
            _language = read_uint16(io)
            seg_count_x2 = read_uint16(io)
            seg_count = seg_count_x2 // 2

            _search_range = read_uint16(io)
            _entry_selector = read_uint16(io)
            _range_shift = read_uint16(io)

            # Read end codes
            end_codes = Array(UInt16).new(seg_count.to_i)
            seg_count.times { end_codes << read_uint16(io) }

            _reserved_pad = read_uint16(io)

            # Read start codes
            start_codes = Array(UInt16).new(seg_count.to_i)
            seg_count.times { start_codes << read_uint16(io) }

            # Read id deltas
            id_deltas = Array(Int16).new(seg_count.to_i)
            seg_count.times { id_deltas << read_int16(io) }

            # Remember position before id range offsets
            id_range_offset_start = io.pos

            # Read id range offsets
            id_range_offsets = Array(UInt16).new(seg_count.to_i)
            seg_count.times { id_range_offsets << read_uint16(io) }

            mapping = Hash(UInt32, UInt16).new

            seg_count.times do |i|
              start_code = start_codes[i]
              end_code = end_codes[i]
              id_delta = id_deltas[i]
              id_range_offset = id_range_offsets[i]

              # Skip the end marker segment
              next if start_code == 0xFFFF

              if id_range_offset == 0
                # Use delta to calculate glyph ID
                (start_code..end_code).each do |code|
                  glyph_id = ((code.to_i32 + id_delta.to_i32) & 0xFFFF).to_u16
                  mapping[code.to_u32] = glyph_id if glyph_id != 0
                end
              else
                # Use glyphIdArray
                (start_code..end_code).each do |code|
                  # Calculate offset into glyphIdArray
                  offset_in_segment = code - start_code
                  glyph_array_offset = id_range_offset_start + (i * 2) + id_range_offset + (offset_in_segment * 2)

                  if glyph_array_offset + 1 < raw_data.size
                    glyph_io = IO::Memory.new(raw_data[glyph_array_offset..])
                    glyph_id = read_uint16(glyph_io)
                    if glyph_id != 0
                      glyph_id = ((glyph_id.to_i32 + id_delta.to_i32) & 0xFFFF).to_u16
                      mapping[code.to_u32] = glyph_id
                    end
                  end
                end
              end
            end

            mapping
          end

          # Format 6: Trimmed table mapping
          private def self.parse_format6(io : IO) : Hash(UInt32, UInt16)
            _length = read_uint16(io)
            _language = read_uint16(io)
            first_code = read_uint16(io)
            entry_count = read_uint16(io)

            mapping = Hash(UInt32, UInt16).new
            entry_count.times do |i|
              glyph_id = read_uint16(io)
              code = first_code + i
              mapping[code.to_u32] = glyph_id if glyph_id != 0
            end
            mapping
          end

          # Format 12: Segmented coverage (full Unicode)
          private def self.parse_format12(io : IO) : Hash(UInt32, UInt16)
            _reserved = read_uint16(io)
            _length = read_uint32(io)
            _language = read_uint32(io)
            num_groups = read_uint32(io)

            mapping = Hash(UInt32, UInt16).new

            num_groups.times do
              start_char_code = read_uint32(io)
              end_char_code = read_uint32(io)
              start_glyph_id = read_uint32(io)

              (start_char_code..end_char_code).each do |code|
                glyph_id = (start_glyph_id + (code - start_char_code)).to_u16
                mapping[code] = glyph_id if glyph_id != 0
              end
            end

            mapping
          end

          # Find the best Unicode subtable
          private def find_best_unicode_subtable : UInt32?
            # Prefer format 12 (full Unicode) over format 4 (BMP)
            # Prefer platform 3 (Windows) over platform 0 (Unicode)

            best : EncodingRecord? = nil
            best_score = -1

            @encoding_records.each do |record|
              next unless record.unicode?
              next unless @subtables.has_key?(record.offset)

              # Calculate score based on platform and encoding
              score = 0
              score += 10 if record.platform_id == 3 # Windows
              score += 5 if record.encoding_id == 10 # UCS-4

              if score > best_score
                best = record
                best_score = score
              end
            end

            best.try(&.offset)
          end

          # Get the glyph ID for a Unicode codepoint
          def glyph_id(codepoint : UInt32) : UInt16?
            if offset = @unicode_subtable_offset
              @subtables[offset]?.try(&.[codepoint]?)
            else
              # Try all subtables
              @subtables.each_value do |mapping|
                if glyph = mapping[codepoint]?
                  return glyph
                end
              end
              nil
            end
          end

          # Get the glyph ID for a character
          def glyph_id(char : Char) : UInt16?
            glyph_id(char.ord.to_u32)
          end

          # Get the Unicode to glyph mapping
          def unicode_mapping : Hash(UInt32, UInt16)
            if offset = @unicode_subtable_offset
              @subtables[offset]? || Hash(UInt32, UInt16).new
            else
              # Merge all subtables
              result = Hash(UInt32, UInt16).new
              @subtables.each_value { |m| result.merge!(m) }
              result
            end
          end

          # Encode a new cmap table with the given mapping
          def self.encode(mapping : Hash(UInt32, UInt16)) : Bytes
            io = IO::Memory.new

            # We'll create a format 4 subtable for BMP and format 12 for full Unicode
            has_non_bmp = mapping.any? { |code, _| code > 0xFFFF }

            # Version and number of tables
            write_uint16(io, 0_u16)                       # version
            write_uint16(io, has_non_bmp ? 2_u16 : 1_u16) # numTables

            # Calculate offsets
            header_size = 4 # version + numTables
            encoding_record_size = 8
            format4_offset = header_size + (has_non_bmp ? 2 : 1) * encoding_record_size

            # Encoding record for format 4 (Windows Unicode BMP)
            write_uint16(io, 3_u16) # platformID
            write_uint16(io, 1_u16) # encodingID
            write_uint32(io, format4_offset.to_u32)

            format12_offset_pos = 0
            if has_non_bmp
              # Placeholder for format 12 offset, we'll update it later
              format12_offset_pos = io.pos
              write_uint16(io, 3_u16)  # platformID
              write_uint16(io, 10_u16) # encodingID
              write_uint32(io, 0_u32)  # offset (placeholder)
            end

            # Write format 4 subtable (BMP only)
            write_format4(io, mapping.select { |code, _| code <= 0xFFFF })

            if has_non_bmp
              # Update format 12 offset
              format12_offset = io.pos
              io.seek(format12_offset_pos + 6)
              write_uint32(io, format12_offset.to_u32)
              io.seek(format12_offset)

              # Write format 12 subtable
              write_format12(io, mapping)
            end

            io.to_slice
          end

          # Write a format 4 subtable
          private def self.write_format4(io : IO, mapping : Hash(UInt32, UInt16)) : Nil
            # Build segments
            segments = build_format4_segments(mapping)

            seg_count = segments.size
            seg_count_x2 = seg_count * 2
            search_range = 2 * (2 ** Math.log2(seg_count).floor.to_i)
            entry_selector = Math.log2(search_range / 2).floor.to_i
            range_shift = seg_count_x2 - search_range

            # Calculate length
            glyph_id_array_size = segments.sum { |s| s[:glyph_ids].size * 2 }
            length = 16 + (seg_count * 8) + glyph_id_array_size

            write_uint16(io, 4_u16) # format
            write_uint16(io, length.to_u16)
            write_uint16(io, 0_u16) # language
            write_uint16(io, seg_count_x2.to_u16)
            write_uint16(io, search_range.to_u16)
            write_uint16(io, entry_selector.to_u16)
            write_uint16(io, range_shift.to_u16)

            # End codes
            segments.each { |s| write_uint16(io, s[:end_code].to_u16) }
            write_uint16(io, 0_u16) # reservedPad

            # Start codes
            segments.each { |s| write_uint16(io, s[:start_code].to_u16) }

            # ID deltas (mod 65536 to handle overflow, then wrap to signed Int16)
            segments.each do |s|
              # The delta is computed modulo 65536 since glyph IDs are 16-bit
              delta_mod = s[:id_delta] & 0xFFFF
              write_int16(io, delta_mod.to_i16!)
            end

            # ID range offsets
            offset = segments.size * 2 # Offset from current position to glyphIdArray
            segments.each_with_index do |s, i|
              if s[:use_delta]
                write_uint16(io, 0_u16)
              else
                # Calculate offset to this segment's glyph IDs
                glyph_offset = offset + segments[0...i].sum { |seg| seg[:glyph_ids].size * 2 }
                write_uint16(io, glyph_offset.to_u16)
              end
              offset -= 2
            end

            # Glyph ID array
            segments.each do |s|
              s[:glyph_ids].each { |id| write_uint16(io, id) }
            end
          end

          # Build segments for format 4
          private def self.build_format4_segments(mapping : Hash(UInt32, UInt16))
            return [{start_code: 0xFFFF, end_code: 0xFFFF, id_delta: 1, use_delta: true, glyph_ids: [] of UInt16}] if mapping.empty?

            # Sort by character code
            sorted = mapping.to_a.sort_by { |code, _| code }

            segments = [] of NamedTuple(start_code: UInt32, end_code: UInt32, id_delta: Int32, use_delta: Bool, glyph_ids: Array(UInt16))

            current_start = sorted.first[0]
            current_end = current_start
            current_glyph_start = sorted.first[1].to_i32

            sorted.each_with_index do |(code, glyph), i|
              next if i == 0

              prev_code, prev_glyph = sorted[i - 1]
              expected_glyph = prev_glyph.to_i32 + (code.to_i32 - prev_code.to_i32)

              if code == prev_code + 1 && glyph.to_i32 == expected_glyph
                # Continue current segment
                current_end = code
              else
                # End current segment
                id_delta = current_glyph_start - current_start.to_i32
                segments << {
                  start_code: current_start,
                  end_code:   current_end,
                  id_delta:   id_delta,
                  use_delta:  true,
                  glyph_ids:  [] of UInt16,
                }

                # Start new segment
                current_start = code
                current_end = code
                current_glyph_start = glyph.to_i32
              end
            end

            # Add final segment
            id_delta = current_glyph_start - current_start.to_i32
            segments << {
              start_code: current_start,
              end_code:   current_end,
              id_delta:   id_delta,
              use_delta:  true,
              glyph_ids:  [] of UInt16,
            }

            # Add end marker
            segments << {
              start_code: 0xFFFF_u32,
              end_code:   0xFFFF_u32,
              id_delta:   1,
              use_delta:  true,
              glyph_ids:  [] of UInt16,
            }

            segments
          end

          # Write a format 12 subtable
          private def self.write_format12(io : IO, mapping : Hash(UInt32, UInt16)) : Nil
            # Build groups
            groups = build_format12_groups(mapping)

            length = 16 + (groups.size * 12)

            write_uint16(io, 12_u16) # format
            write_uint16(io, 0_u16)  # reserved
            write_uint32(io, length.to_u32)
            write_uint32(io, 0_u32) # language
            write_uint32(io, groups.size.to_u32)

            groups.each do |group|
              write_uint32(io, group[:start_char_code])
              write_uint32(io, group[:end_char_code])
              write_uint32(io, group[:start_glyph_id])
            end
          end

          # Build groups for format 12
          private def self.build_format12_groups(mapping : Hash(UInt32, UInt16))
            return [] of NamedTuple(start_char_code: UInt32, end_char_code: UInt32, start_glyph_id: UInt32) if mapping.empty?

            # Sort by character code
            sorted = mapping.to_a.sort_by { |code, _| code }

            groups = [] of NamedTuple(start_char_code: UInt32, end_char_code: UInt32, start_glyph_id: UInt32)

            current_start = sorted.first[0]
            current_end = current_start
            current_glyph_start = sorted.first[1].to_u32

            sorted.each_with_index do |(code, glyph), i|
              next if i == 0

              prev_code, prev_glyph = sorted[i - 1]
              expected_glyph = prev_glyph + 1

              if code == prev_code + 1 && glyph.to_u32 == expected_glyph.to_u32
                # Continue current group
                current_end = code
              else
                # End current group
                groups << {
                  start_char_code: current_start,
                  end_char_code:   current_end,
                  start_glyph_id:  current_glyph_start,
                }

                # Start new group
                current_start = code
                current_end = code
                current_glyph_start = glyph.to_u32
              end
            end

            # Add final group
            groups << {
              start_char_code: current_start,
              end_char_code:   current_end,
              start_glyph_id:  current_glyph_start,
            }

            groups
          end

          extend IOHelpers
        end
      end
    end
  end
end
