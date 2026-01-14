module PDF
  module Fonts
    module TrueType
      module Tables
        # Horizontal metric record for a glyph
        struct HMetric
          # Advance width in font units
          getter advance_width : UInt16

          # Left side bearing in font units
          getter left_side_bearing : Int16

          def initialize(@advance_width : UInt16, @left_side_bearing : Int16)
          end
        end

        # The 'hmtx' table contains horizontal metrics for each glyph.
        # This table is required for horizontal writing.
        class Hmtx
          include IOHelpers

          # Horizontal metrics for each glyph with full metrics
          getter h_metrics : Array(HMetric)

          # Left side bearings for glyphs beyond number_of_h_metrics
          getter left_side_bearings : Array(Int16)

          def initialize(@h_metrics : Array(HMetric), @left_side_bearings : Array(Int16))
          end

          # Parse the hmtx table from raw bytes
          # Requires number_of_h_metrics from hhea and num_glyphs from maxp
          def self.parse(data : Bytes, number_of_h_metrics : UInt16, num_glyphs : UInt16) : Hmtx
            io = IO::Memory.new(data)
            parse(io, number_of_h_metrics, num_glyphs)
          end

          # Parse the hmtx table from an IO
          def self.parse(io : IO, number_of_h_metrics : UInt16, num_glyphs : UInt16) : Hmtx
            h_metrics = Array(HMetric).new(number_of_h_metrics.to_i)

            number_of_h_metrics.times do
              advance_width = read_uint16(io)
              left_side_bearing = read_int16(io)
              h_metrics << HMetric.new(advance_width, left_side_bearing)
            end

            # Remaining glyphs only have left side bearing
            remaining = num_glyphs.to_i - number_of_h_metrics.to_i
            left_side_bearings = Array(Int16).new(remaining)

            remaining.times do
              left_side_bearings << read_int16(io)
            end

            new(h_metrics, left_side_bearings)
          end

          # Get the advance width for a glyph
          def advance_width(glyph_id : UInt16) : UInt16
            if glyph_id < @h_metrics.size
              @h_metrics[glyph_id].advance_width
            else
              # Glyphs beyond number_of_h_metrics use the last advance width
              @h_metrics.last?.try(&.advance_width) || 0_u16
            end
          end

          # Get the left side bearing for a glyph
          def left_side_bearing(glyph_id : UInt16) : Int16
            if glyph_id < @h_metrics.size
              @h_metrics[glyph_id].left_side_bearing
            else
              idx = glyph_id.to_i - @h_metrics.size
              if idx >= 0 && idx < @left_side_bearings.size
                @left_side_bearings[idx]
              else
                0_i16
              end
            end
          end

          # Serialize this table to bytes
          def to_bytes : Bytes
            io = IO::Memory.new
            write(io)
            io.to_slice
          end

          # Write this table to an IO
          def write(io : IO) : Nil
            @h_metrics.each do |metric|
              write_uint16(io, metric.advance_width)
              write_int16(io, metric.left_side_bearing)
            end
            @left_side_bearings.each do |lsb|
              write_int16(io, lsb)
            end
          end

          # Create a new hmtx table with only the specified glyph IDs
          # glyph_id_map maps old glyph IDs to new glyph IDs
          def subset(glyph_id_map : Hash(UInt16, UInt16)) : Hmtx
            # Collect metrics for subset glyphs in order of new glyph IDs
            sorted_entries = glyph_id_map.to_a.sort_by { |_, new_id| new_id }

            new_metrics = sorted_entries.map do |old_id, _|
              HMetric.new(advance_width(old_id), left_side_bearing(old_id))
            end

            # For simplicity, all glyphs in the subset have full metrics
            Hmtx.new(new_metrics, [] of Int16)
          end

          extend IOHelpers
        end
      end
    end
  end
end
