module PDF
  module Fonts
    module TrueType
      module Tables
        # The 'hhea' table contains horizontal header information.
        # This table is required for fonts with horizontal writing.
        class Hhea
          include IOHelpers

          # Major version (should be 1)
          getter major_version : UInt16

          # Minor version (should be 0)
          getter minor_version : UInt16

          # Typographic ascent (distance from baseline to top)
          getter ascent : Int16

          # Typographic descent (distance from baseline to bottom, usually negative)
          getter descent : Int16

          # Typographic line gap
          getter line_gap : Int16

          # Maximum advance width in 'hmtx' table
          getter advance_width_max : UInt16

          # Minimum left side bearing in 'hmtx' table
          getter min_left_side_bearing : Int16

          # Minimum right side bearing
          getter min_right_side_bearing : Int16

          # Maximum x extent (max of xMax - lsb)
          getter x_max_extent : Int16

          # Caret slope rise (used for italic fonts)
          getter caret_slope_rise : Int16

          # Caret slope run (used for italic fonts)
          getter caret_slope_run : Int16

          # Caret offset
          getter caret_offset : Int16

          # Reserved fields (should be 0)
          @reserved1 : Int16
          @reserved2 : Int16
          @reserved3 : Int16
          @reserved4 : Int16

          # Metric data format (should be 0)
          getter metric_data_format : Int16

          # Number of full horizontal metrics in 'hmtx' table
          getter number_of_h_metrics : UInt16

          def initialize(
            @major_version : UInt16,
            @minor_version : UInt16,
            @ascent : Int16,
            @descent : Int16,
            @line_gap : Int16,
            @advance_width_max : UInt16,
            @min_left_side_bearing : Int16,
            @min_right_side_bearing : Int16,
            @x_max_extent : Int16,
            @caret_slope_rise : Int16,
            @caret_slope_run : Int16,
            @caret_offset : Int16,
            @reserved1 : Int16,
            @reserved2 : Int16,
            @reserved3 : Int16,
            @reserved4 : Int16,
            @metric_data_format : Int16,
            @number_of_h_metrics : UInt16
          )
          end

          # Parse the hhea table from raw bytes
          def self.parse(data : Bytes) : Hhea
            io = IO::Memory.new(data)
            parse(io)
          end

          # Parse the hhea table from an IO
          def self.parse(io : IO) : Hhea
            major_version = read_uint16(io)
            minor_version = read_uint16(io)
            ascent = read_int16(io)
            descent = read_int16(io)
            line_gap = read_int16(io)
            advance_width_max = read_uint16(io)
            min_left_side_bearing = read_int16(io)
            min_right_side_bearing = read_int16(io)
            x_max_extent = read_int16(io)
            caret_slope_rise = read_int16(io)
            caret_slope_run = read_int16(io)
            caret_offset = read_int16(io)
            reserved1 = read_int16(io)
            reserved2 = read_int16(io)
            reserved3 = read_int16(io)
            reserved4 = read_int16(io)
            metric_data_format = read_int16(io)
            number_of_h_metrics = read_uint16(io)

            new(
              major_version, minor_version, ascent, descent, line_gap,
              advance_width_max, min_left_side_bearing, min_right_side_bearing,
              x_max_extent, caret_slope_rise, caret_slope_run, caret_offset,
              reserved1, reserved2, reserved3, reserved4,
              metric_data_format, number_of_h_metrics
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
            write_int16(io, @ascent)
            write_int16(io, @descent)
            write_int16(io, @line_gap)
            write_uint16(io, @advance_width_max)
            write_int16(io, @min_left_side_bearing)
            write_int16(io, @min_right_side_bearing)
            write_int16(io, @x_max_extent)
            write_int16(io, @caret_slope_rise)
            write_int16(io, @caret_slope_run)
            write_int16(io, @caret_offset)
            write_int16(io, @reserved1)
            write_int16(io, @reserved2)
            write_int16(io, @reserved3)
            write_int16(io, @reserved4)
            write_int16(io, @metric_data_format)
            write_uint16(io, @number_of_h_metrics)
          end

          extend IOHelpers
        end
      end
    end
  end
end
