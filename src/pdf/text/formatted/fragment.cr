module PDF
  module Text
    module Formatted
      # Represents a single fragment of formatted text with its associated
      # style information. A fragment is the smallest unit of text that
      # shares the same formatting (font, size, color, styles).
      #
      # Ported from Prawn::Text::Formatted::Fragment.
      #
      # ```
      # fragment = Fragment.new("Hello", {styles: [:bold], color: "FF0000"})
      # fragment.bold?   # => true
      # fragment.italic? # => false
      # ```
      class Fragment
        # The text content of this fragment
        property text : String

        # Width of the fragment in points (set during measurement)
        property width : Float64 = 0.0

        # Line height of the fragment in points
        property line_height : Float64 = 0.0

        # Descender depth (positive value, measured downward from baseline)
        property descender : Float64 = 0.0

        # Ascender height (positive value, measured upward from baseline)
        property ascender : Float64 = 0.0

        # Word spacing adjustment for justified text
        property word_spacing : Float64 = 0.0

        # Horizontal position of the fragment (set during drawing)
        property left : Float64 = 0.0

        # Baseline vertical position (set during drawing)
        property baseline : Float64 = 0.0

        # The format state hash for this fragment
        getter format_state : FormatState

        def initialize(@text : String, @format_state : FormatState = FormatState.new)
        end

        # Returns the actual width including word spacing adjustments.
        def actual_width : Float64
          if @word_spacing == 0.0
            @width
          else
            @width + (@word_spacing * space_count)
          end
        end

        # Returns the height of the fragment (ascender + descender).
        def height : Float64
          @ascender + @descender
        end

        # Whether this fragment has the bold style.
        def bold? : Bool
          @format_state.styles.includes?(:bold)
        end

        # Returns the color for this fragment, if any.
        def color : String?
          @format_state.color
        end

        # Returns the font name for this fragment, if any.
        def font : String?
          @format_state.font
        end

        # Whether this fragment has the italic style.
        def italic? : Bool
          @format_state.styles.includes?(:italic)
        end

        # Right edge position.
        def right : Float64
          @left + actual_width
        end

        # Returns the font size for this fragment, if any.
        def size : Float64?
          @format_state.size
        end

        # Number of space characters in the text.
        def space_count : Int32
          @text.count(' ')
        end

        # Whether this fragment has the strikethrough style.
        def strikethrough? : Bool
          @format_state.styles.includes?(:strikethrough)
        end

        # Returns the styles for this fragment.
        def styles : Array(Symbol)
          @format_state.styles
        end

        # Whether this fragment has the subscript style.
        def subscript? : Bool
          @format_state.styles.includes?(:subscript)
        end

        # Whether this fragment has the superscript style.
        def superscript? : Bool
          @format_state.styles.includes?(:superscript)
        end

        # Top edge position.
        def top : Float64
          @baseline + @ascender
        end

        # Bottom edge position.
        def bottom : Float64
          @baseline - @descender
        end

        # Whether this fragment has the underline style.
        def underline? : Bool
          @format_state.styles.includes?(:underline)
        end

        # Vertical offset for subscript/superscript positioning.
        def y_offset : Float64
          if subscript?
            -@descender
          elsif superscript?
            0.85 * @ascender
          else
            0.0
          end
        end
      end

      # Holds the formatting state for a text fragment.
      class FormatState
        # Text color as a hex string (e.g., "FF0000")
        property color : String?

        # Font name override
        property font : String?

        # Font size override
        property size : Float64?

        # Array of style symbols (:bold, :italic, :underline, :strikethrough,
        # :subscript, :superscript)
        property styles : Array(Symbol)

        def initialize(
          @styles : Array(Symbol) = [] of Symbol,
          @color : String? = nil,
          @font : String? = nil,
          @size : Float64? = nil,
        )
        end

        # Converts this format state to a FragmentHash.
        def to_hash : FragmentHash
          hash = FragmentHash.new
          hash[:styles] = @styles
          hash[:color] = @color
          hash[:font] = @font
          hash[:size] = @size
          hash
        end
      end
    end
  end
end
