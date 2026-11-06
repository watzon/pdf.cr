module PDF
  module Text
    module Formatted
      # Manages the two-stage processing of formatted text fragments.
      # Fragments are consumed from an input array during line wrapping,
      # then finalized into measured `Fragment` objects for rendering.
      #
      # Ported from Prawn::Text::Formatted::Arranger.
      class Arranger
        # Maximum line height among all fragments on the current line.
        getter max_line_height : Float64 = 0.0

        # Maximum descender among all fragments on the current line.
        getter max_descender : Float64 = 0.0

        # Maximum ascender among all fragments on the current line.
        getter max_ascender : Float64 = 0.0

        # The finalized fragments for the current line.
        getter fragments : Array(Fragment) = [] of Fragment

        # The consumed (printed) fragment hashes for the current line.
        getter consumed : Array(FragmentHash) = [] of FragmentHash

        # The unconsumed (remaining) fragment hashes.
        getter unconsumed : Array(FragmentHash) = [] of FragmentHash

        # The current format state (set when consuming fragments).
        getter current_format_state : FormatState = FormatState.new

        # Whether the current line has been finalized.
        getter? finalized : Bool = false

        # The unconsumed fragments when the current line started. Line
        # wrapping changes the consumed copies (it strips, splits and drops
        # text), so `#repack_unretrieved` restores this list instead.
        # Consumed fragments are copies, so these hashes do not change.
        @line_start_unconsumed = [] of FragmentHash

        def initialize
          @consumed = [] of FragmentHash
          @unconsumed = [] of FragmentHash
          @fragments = [] of Fragment
          @current_format_state = FormatState.new
          @finalized = false
          @max_line_height = 0.0
          @max_descender = 0.0
          @max_ascender = 0.0
        end

        # Whether all fragments have been consumed.
        def finished? : Bool
          @unconsumed.empty?
        end

        # Sets the input array of formatted text. Each hash is split on
        # newlines so that each entry contains at most one line.
        def format_array=(array : Array(FragmentHash)) : Nil
          initialize_line
          @unconsumed = [] of FragmentHash
          array.each do |hash|
            # Split text on newlines, preserving the newline as a separate entry
            text = hash[:text].as(String)
            parts = text.scan(/[^\n]+|\n/)
            parts.each do |match|
              new_hash = hash.dup
              new_hash[:text] = match[0]
              @unconsumed << new_hash
            end
          end
          @line_start_unconsumed = @unconsumed.dup
        end

        # Prepares for processing a new line.
        def initialize_line : Nil
          @finalized = false
          @line_start_unconsumed = @unconsumed.dup
          @max_line_height = 0.0
          @max_descender = 0.0
          @max_ascender = 0.0
          @consumed = [] of FragmentHash
          @fragments = [] of Fragment
        end

        # Returns the text of the current finalized line.
        def line : String
          raise "Lines must be finalized before calling #line" unless @finalized
          @fragments.map(&.text).join
        end

        # Returns the total width of the current finalized line.
        def line_width : Float64
          raise "Lines must be finalized before calling #line_width" unless @finalized
          @fragments.sum(&.actual_width)
        end

        # Consumes and returns the next fragment's text string.
        # Returns nil if no more fragments are available.
        def next_string : String?
          return if @unconsumed.empty?

          hash = @unconsumed.shift
          @consumed << hash.dup
          @current_format_state = FormatState.new(
            styles: hash[:styles]? ? hash[:styles].as(Array(Symbol)) : [] of Symbol,
            color: hash[:color]?.as(String?),
            font: hash[:font]?.as(String?),
            size: hash[:size]?.as(Float64?),
          )
          hash[:text].as(String)
        end

        # Peeks at the next fragment's text without consuming it.
        def preview_next_string : String?
          return if @unconsumed.empty?
          @unconsumed.first[:text].as(String)
        end

        # Returns the total number of spaces in the finalized line.
        def space_count : Int32
          raise "Lines must be finalized before calling #space_count" unless @finalized
          @fragments.sum(&.space_count)
        end

        # Updates the last consumed fragment with the printed and remaining text.
        def update_last_string(printed : String, remaining : String) : Nil
          if printed.empty?
            @consumed.pop unless @consumed.empty?
          else
            @consumed.last[:text] = printed unless @consumed.empty?
          end

          unless remaining.empty?
            remaining_hash = @current_format_state.to_hash
            remaining_hash[:text] = remaining
            @unconsumed.unshift(remaining_hash)
          end
        end

        # Moves the last word of the line back to the unconsumed text, so that
        # it starts the next line. The word starts after the last space, tab
        # or hyphen of the line and can span several fragments (for example
        # `H` and a subscript `2`). Returns `false`, and changes nothing, when
        # the line has no such break point before the word.
        def unconsume_trailing_word : Bool
          index = @consumed.rindex { |hash| BREAK_CHARACTER.matches?(hash[:text].as(String)) }
          return false unless index

          text = @consumed[index][:text].as(String)
          cut = (text.rindex(BREAK_CHARACTER) || return false) + 1
          return false if index == 0 && text[0...cut].blank?

          moved = @consumed[(index + 1)..].map(&.dup)
          if cut < text.size
            tail = @consumed[index].dup
            tail[:text] = text[cut..]
            moved.unshift(tail)
            @consumed[index][:text] = text[0...cut]
          end
          @consumed = @consumed[0..index]
          @unconsumed = moved + @unconsumed
          true
        end

        # A character after which a line can break.
        BREAK_CHARACTER = /[ \t-]/

        # Finalizes the current line by creating Fragment objects from
        # consumed hashes and measuring them.
        def finalize_line(font_measurer : FontMeasurer) : Nil
          @finalized = true

          # Remove trailing whitespace from width calculations
          omit_trailing_whitespace

          @fragments = [] of Fragment
          @consumed.each do |hash|
            text = hash[:text].as(String)
            format_state = FormatState.new(
              styles: hash[:styles]? ? hash[:styles].as(Array(Symbol)) : [] of Symbol,
              color: hash[:color]?.as(String?),
              font: hash[:font]?.as(String?),
              size: hash[:size]?.as(Float64?),
            )
            fragment = Fragment.new(text, format_state)

            # Measure the fragment
            fragment.width = font_measurer.measure_width(text, format_state)
            metrics = font_measurer.metrics(format_state)
            fragment.line_height = metrics[:line_height]
            fragment.descender = metrics[:descender]
            fragment.ascender = metrics[:ascender]

            @fragments << fragment

            # Update maximums
            @max_line_height = Math.max(@max_line_height, fragment.line_height)
            @max_descender = Math.max(@max_descender, fragment.descender)
            @max_ascender = Math.max(@max_ascender, fragment.ascender)
          end
        end

        # Sets the line metrics of an empty line from the current format state,
        # so that blank lines advance the baseline like text lines do.
        def use_blank_line_metrics(font_measurer : FontMeasurer) : Nil
          metrics = font_measurer.metrics(@current_format_state)
          @max_line_height = metrics[:line_height]
          @max_descender = metrics[:descender]
          @max_ascender = metrics[:ascender]
        end

        # Puts the fragments of the current line back, as they were when the
        # line started (used when the line doesn't fit).
        def repack_unretrieved : Nil
          @unconsumed = @line_start_unconsumed.dup
          @consumed.clear
        end

        private def omit_trailing_whitespace : Nil
          @consumed.reverse_each do |hash|
            text = hash[:text].as(String)
            if text == "\n"
              break
            elsif text.strip.empty? && @consumed.size > 1
              hash[:exclude_trailing_white_space] = true
            else
              hash[:exclude_trailing_white_space] = true
              break
            end
          end
        end
      end

      # A hash representing a fragment of formatted text.
      # Keys: :text (String), :styles (Array(Symbol)), :color (String?),
      #        :font (String?), :size (Float64?)
      alias FragmentHash = Hash(Symbol, String | Array(Symbol) | Float64 | Bool?)

      # Converts an array of named tuples or hashes (for example
      # `[{text: "Hi", styles: [:bold]}]`) into `FragmentHash` values.
      # Integer and Float32 values become Float64.
      def self.to_fragment_hashes(fragments : Array) : Array(FragmentHash)
        fragments.map { |fragment| to_fragment_hash(fragment.to_h) }
      end

      # Converts formatted text input to `FragmentHash` values: a markup
      # string is parsed with `Parser.format`, fragment hashes are returned
      # as they are, and other arrays (named tuples) use
      # `to_fragment_hashes`.
      def self.coerce(fragments : String) : Array(FragmentHash)
        Parser.format(fragments)
      end

      # :ditto:
      def self.coerce(fragments : Array(FragmentHash)) : Array(FragmentHash)
        fragments
      end

      # :ditto:
      def self.coerce(fragments : Array) : Array(FragmentHash)
        to_fragment_hashes(fragments)
      end

      private def self.to_fragment_hash(source : Hash) : FragmentHash
        hash = FragmentHash.new
        source.each do |key, value|
          case value
          when String, Array(Symbol), Float64, Bool, Nil
            hash[key] = value
          when Int, Float32
            hash[key] = value.to_f64
          else
            raise ArgumentError.new("Unsupported value for #{key.inspect}: #{value.inspect}")
          end
        end
        hash
      end
    end
  end
end
