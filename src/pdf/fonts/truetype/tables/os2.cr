module PDF
  module Fonts
    module TrueType
      module Tables
        # The 'OS/2' table contains OS/2 and Windows-specific metrics.
        # This table is required for OpenType fonts.
        class OS2
          include IOHelpers

          # Table version
          getter version : UInt16

          # Average weighted width of lowercase letters and space
          getter x_avg_char_width : Int16

          # Weight class (100-900, 400 = normal, 700 = bold)
          getter weight_class : UInt16

          # Width class (1-9, 5 = normal)
          getter width_class : UInt16

          # Type flags (embedding permissions)
          getter fs_type : UInt16

          # Subscript sizes and offsets
          getter y_subscript_x_size : Int16
          getter y_subscript_y_size : Int16
          getter y_subscript_x_offset : Int16
          getter y_subscript_y_offset : Int16

          # Superscript sizes and offsets
          getter y_superscript_x_size : Int16
          getter y_superscript_y_size : Int16
          getter y_superscript_x_offset : Int16
          getter y_superscript_y_offset : Int16

          # Strikeout size and position
          getter y_strikeout_size : Int16
          getter y_strikeout_position : Int16

          # Font family class
          getter s_family_class : Int16

          # PANOSE classification
          getter panose : Bytes

          # Unicode range bits
          getter ul_unicode_range1 : UInt32
          getter ul_unicode_range2 : UInt32
          getter ul_unicode_range3 : UInt32
          getter ul_unicode_range4 : UInt32

          # Vendor ID
          getter ach_vend_id : String

          # Font selection flags
          getter fs_selection : UInt16

          # First and last character indices
          getter us_first_char_index : UInt16
          getter us_last_char_index : UInt16

          # Typographic metrics
          getter s_typo_ascender : Int16
          getter s_typo_descender : Int16
          getter s_typo_line_gap : Int16
          getter us_win_ascent : UInt16
          getter us_win_descent : UInt16

          # Code page ranges (version 1+)
          getter ul_code_page_range1 : UInt32?
          getter ul_code_page_range2 : UInt32?

          # Additional metrics (version 2+)
          getter sx_height : Int16?
          getter s_cap_height : Int16?
          getter us_default_char : UInt16?
          getter us_break_char : UInt16?
          getter us_max_context : UInt16?

          # Lower/upper optical point sizes (version 5+)
          getter us_lower_optical_point_size : UInt16?
          getter us_upper_optical_point_size : UInt16?

          def initialize(
            @version : UInt16,
            @x_avg_char_width : Int16,
            @weight_class : UInt16,
            @width_class : UInt16,
            @fs_type : UInt16,
            @y_subscript_x_size : Int16,
            @y_subscript_y_size : Int16,
            @y_subscript_x_offset : Int16,
            @y_subscript_y_offset : Int16,
            @y_superscript_x_size : Int16,
            @y_superscript_y_size : Int16,
            @y_superscript_x_offset : Int16,
            @y_superscript_y_offset : Int16,
            @y_strikeout_size : Int16,
            @y_strikeout_position : Int16,
            @s_family_class : Int16,
            @panose : Bytes,
            @ul_unicode_range1 : UInt32,
            @ul_unicode_range2 : UInt32,
            @ul_unicode_range3 : UInt32,
            @ul_unicode_range4 : UInt32,
            @ach_vend_id : String,
            @fs_selection : UInt16,
            @us_first_char_index : UInt16,
            @us_last_char_index : UInt16,
            @s_typo_ascender : Int16,
            @s_typo_descender : Int16,
            @s_typo_line_gap : Int16,
            @us_win_ascent : UInt16,
            @us_win_descent : UInt16,
            @ul_code_page_range1 : UInt32? = nil,
            @ul_code_page_range2 : UInt32? = nil,
            @sx_height : Int16? = nil,
            @s_cap_height : Int16? = nil,
            @us_default_char : UInt16? = nil,
            @us_break_char : UInt16? = nil,
            @us_max_context : UInt16? = nil,
            @us_lower_optical_point_size : UInt16? = nil,
            @us_upper_optical_point_size : UInt16? = nil
          )
          end

          # Parse the OS/2 table from raw bytes
          def self.parse(data : Bytes) : OS2
            io = IO::Memory.new(data)
            parse(io, data.size)
          end

          # Parse the OS/2 table from an IO
          def self.parse(io : IO, data_size : Int32) : OS2
            version = read_uint16(io)
            x_avg_char_width = read_int16(io)
            weight_class = read_uint16(io)
            width_class = read_uint16(io)
            fs_type = read_uint16(io)
            y_subscript_x_size = read_int16(io)
            y_subscript_y_size = read_int16(io)
            y_subscript_x_offset = read_int16(io)
            y_subscript_y_offset = read_int16(io)
            y_superscript_x_size = read_int16(io)
            y_superscript_y_size = read_int16(io)
            y_superscript_x_offset = read_int16(io)
            y_superscript_y_offset = read_int16(io)
            y_strikeout_size = read_int16(io)
            y_strikeout_position = read_int16(io)
            s_family_class = read_int16(io)
            panose = read_bytes(io, 10)
            ul_unicode_range1 = read_uint32(io)
            ul_unicode_range2 = read_uint32(io)
            ul_unicode_range3 = read_uint32(io)
            ul_unicode_range4 = read_uint32(io)
            ach_vend_id = String.new(read_bytes(io, 4))
            fs_selection = read_uint16(io)
            us_first_char_index = read_uint16(io)
            us_last_char_index = read_uint16(io)
            s_typo_ascender = read_int16(io)
            s_typo_descender = read_int16(io)
            s_typo_line_gap = read_int16(io)
            us_win_ascent = read_uint16(io)
            us_win_descent = read_uint16(io)

            ul_code_page_range1 = nil
            ul_code_page_range2 = nil
            sx_height = nil
            s_cap_height = nil
            us_default_char = nil
            us_break_char = nil
            us_max_context = nil
            us_lower_optical_point_size = nil
            us_upper_optical_point_size = nil

            if version >= 1 && io.pos + 8 <= data_size
              ul_code_page_range1 = read_uint32(io)
              ul_code_page_range2 = read_uint32(io)
            end

            if version >= 2 && io.pos + 10 <= data_size
              sx_height = read_int16(io)
              s_cap_height = read_int16(io)
              us_default_char = read_uint16(io)
              us_break_char = read_uint16(io)
              us_max_context = read_uint16(io)
            end

            if version >= 5 && io.pos + 4 <= data_size
              us_lower_optical_point_size = read_uint16(io)
              us_upper_optical_point_size = read_uint16(io)
            end

            new(
              version, x_avg_char_width, weight_class, width_class, fs_type,
              y_subscript_x_size, y_subscript_y_size, y_subscript_x_offset, y_subscript_y_offset,
              y_superscript_x_size, y_superscript_y_size, y_superscript_x_offset, y_superscript_y_offset,
              y_strikeout_size, y_strikeout_position, s_family_class, panose,
              ul_unicode_range1, ul_unicode_range2, ul_unicode_range3, ul_unicode_range4,
              ach_vend_id, fs_selection, us_first_char_index, us_last_char_index,
              s_typo_ascender, s_typo_descender, s_typo_line_gap, us_win_ascent, us_win_descent,
              ul_code_page_range1, ul_code_page_range2,
              sx_height, s_cap_height, us_default_char, us_break_char, us_max_context,
              us_lower_optical_point_size, us_upper_optical_point_size
            )
          end

          # Check if the font is bold
          def bold? : Bool
            @weight_class >= 700
          end

          # Check if the font is italic
          def italic? : Bool
            (@fs_selection & 0x01) != 0
          end

          # Check if the font uses USE_TYPO_METRICS
          def use_typo_metrics? : Bool
            (@fs_selection & 0x80) != 0
          end

          # Get the effective ascender
          def ascender : Int16
            use_typo_metrics? ? @s_typo_ascender : @us_win_ascent.to_i16
          end

          # Get the effective descender
          def descender : Int16
            use_typo_metrics? ? @s_typo_descender : -@us_win_descent.to_i16
          end

          # Get the cap height (or estimate if not available)
          def cap_height : Int16
            @s_cap_height || (@s_typo_ascender * 0.7).to_i16
          end

          # Serialize the table to bytes
          def to_bytes : Bytes
            io = IO::Memory.new
            write(io)
            io.to_slice
          end

          # Write the table to an IO
          def write(io : IO) : Nil
            write_uint16(io, @version)
            write_int16(io, @x_avg_char_width)
            write_uint16(io, @weight_class)
            write_uint16(io, @width_class)
            write_uint16(io, @fs_type)
            write_int16(io, @y_subscript_x_size)
            write_int16(io, @y_subscript_y_size)
            write_int16(io, @y_subscript_x_offset)
            write_int16(io, @y_subscript_y_offset)
            write_int16(io, @y_superscript_x_size)
            write_int16(io, @y_superscript_y_size)
            write_int16(io, @y_superscript_x_offset)
            write_int16(io, @y_superscript_y_offset)
            write_int16(io, @y_strikeout_size)
            write_int16(io, @y_strikeout_position)
            write_int16(io, @s_family_class)
            io.write(@panose)
            write_uint32(io, @ul_unicode_range1)
            write_uint32(io, @ul_unicode_range2)
            write_uint32(io, @ul_unicode_range3)
            write_uint32(io, @ul_unicode_range4)
            io.write(@ach_vend_id.to_slice[0, 4])
            write_uint16(io, @fs_selection)
            write_uint16(io, @us_first_char_index)
            write_uint16(io, @us_last_char_index)
            write_int16(io, @s_typo_ascender)
            write_int16(io, @s_typo_descender)
            write_int16(io, @s_typo_line_gap)
            write_uint16(io, @us_win_ascent)
            write_uint16(io, @us_win_descent)

            if @version >= 1
              write_uint32(io, @ul_code_page_range1 || 0_u32)
              write_uint32(io, @ul_code_page_range2 || 0_u32)
            end

            if @version >= 2
              write_int16(io, @sx_height || 0_i16)
              write_int16(io, @s_cap_height || 0_i16)
              write_uint16(io, @us_default_char || 0_u16)
              write_uint16(io, @us_break_char || 0_u16)
              write_uint16(io, @us_max_context || 0_u16)
            end

            if @version >= 5
              write_uint16(io, @us_lower_optical_point_size || 0_u16)
              write_uint16(io, @us_upper_optical_point_size || 0_u16)
            end
          end

          extend IOHelpers
        end
      end
    end
  end
end
