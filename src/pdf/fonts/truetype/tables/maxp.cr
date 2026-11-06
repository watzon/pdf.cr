module PDF
  module Fonts
    module TrueType
      module Tables
        # The 'maxp' table contains maximum profile information.
        # This table defines memory requirements for the font.
        class Maxp
          include IOHelpers

          # Version (0x00005000 for CFF, 0x00010000 for TrueType)
          getter version : UInt32

          # Number of glyphs in the font
          getter num_glyphs : UInt16

          # Maximum points in a non-composite glyph (TrueType only)
          getter max_points : UInt16?

          # Maximum contours in a non-composite glyph (TrueType only)
          getter max_contours : UInt16?

          # Maximum points in a composite glyph (TrueType only)
          getter max_composite_points : UInt16?

          # Maximum contours in a composite glyph (TrueType only)
          getter max_composite_contours : UInt16?

          # Max zones (usually 2) (TrueType only)
          getter max_zones : UInt16?

          # Max twilight points (TrueType only)
          getter max_twilight_points : UInt16?

          # Max storage area locations (TrueType only)
          getter max_storage : UInt16?

          # Max function definitions (TrueType only)
          getter max_function_defs : UInt16?

          # Max instruction definitions (TrueType only)
          getter max_instruction_defs : UInt16?

          # Max stack elements (TrueType only)
          getter max_stack_elements : UInt16?

          # Max size of glyph instructions (TrueType only)
          getter max_size_of_instructions : UInt16?

          # Max components at top level (TrueType only)
          getter max_component_elements : UInt16?

          # Max recursion depth (TrueType only)
          getter max_component_depth : UInt16?

          def initialize(
            @version : UInt32,
            @num_glyphs : UInt16,
            @max_points : UInt16? = nil,
            @max_contours : UInt16? = nil,
            @max_composite_points : UInt16? = nil,
            @max_composite_contours : UInt16? = nil,
            @max_zones : UInt16? = nil,
            @max_twilight_points : UInt16? = nil,
            @max_storage : UInt16? = nil,
            @max_function_defs : UInt16? = nil,
            @max_instruction_defs : UInt16? = nil,
            @max_stack_elements : UInt16? = nil,
            @max_size_of_instructions : UInt16? = nil,
            @max_component_elements : UInt16? = nil,
            @max_component_depth : UInt16? = nil,
          )
          end

          # Parse the maxp table from raw bytes
          def self.parse(data : Bytes) : Maxp
            io = IO::Memory.new(data)
            parse(io)
          end

          # Parse the maxp table from an IO
          def self.parse(io : IO) : Maxp
            version = read_uint32(io)
            num_glyphs = read_uint16(io)

            # Version 0.5 (CFF) only has version and numGlyphs
            if version == 0x00005000_u32
              return new(version, num_glyphs)
            end

            # Version 1.0 (TrueType) has additional fields
            max_points = read_uint16(io)
            max_contours = read_uint16(io)
            max_composite_points = read_uint16(io)
            max_composite_contours = read_uint16(io)
            max_zones = read_uint16(io)
            max_twilight_points = read_uint16(io)
            max_storage = read_uint16(io)
            max_function_defs = read_uint16(io)
            max_instruction_defs = read_uint16(io)
            max_stack_elements = read_uint16(io)
            max_size_of_instructions = read_uint16(io)
            max_component_elements = read_uint16(io)
            max_component_depth = read_uint16(io)

            new(
              version, num_glyphs, max_points, max_contours,
              max_composite_points, max_composite_contours,
              max_zones, max_twilight_points, max_storage,
              max_function_defs, max_instruction_defs, max_stack_elements,
              max_size_of_instructions, max_component_elements, max_component_depth
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
            write_uint32(io, @version)
            write_uint16(io, @num_glyphs)

            return if @version == 0x00005000_u32

            write_uint16(io, @max_points.not_nil!)
            write_uint16(io, @max_contours.not_nil!)
            write_uint16(io, @max_composite_points.not_nil!)
            write_uint16(io, @max_composite_contours.not_nil!)
            write_uint16(io, @max_zones.not_nil!)
            write_uint16(io, @max_twilight_points.not_nil!)
            write_uint16(io, @max_storage.not_nil!)
            write_uint16(io, @max_function_defs.not_nil!)
            write_uint16(io, @max_instruction_defs.not_nil!)
            write_uint16(io, @max_stack_elements.not_nil!)
            write_uint16(io, @max_size_of_instructions.not_nil!)
            write_uint16(io, @max_component_elements.not_nil!)
            write_uint16(io, @max_component_depth.not_nil!)
          end

          # Check if this is a TrueType font (version 1.0)
          def truetype? : Bool
            @version == 0x00010000_u32
          end

          # Check if this is a CFF font (version 0.5)
          def cff? : Bool
            @version == 0x00005000_u32
          end

          extend IOHelpers
        end
      end
    end
  end
end
