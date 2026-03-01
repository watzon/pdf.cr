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
        end

        # Prepares for processing a new line.
        def initialize_line : Nil
          @finalized = false
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
          return nil if @unconsumed.empty?

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
          return nil if @unconsumed.empty?
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

        # Repacks unconsumed fragments (used when line doesn't fit).
        def repack_unretrieved : Nil
          new_unconsumed = @consumed.map do |hash|
            hash.dup
          end
          @unconsumed = new_unconsumed + @unconsumed
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
      alias FragmentHash = Hash(Symbol, String | Array(Symbol) | Float64 | Bool | Nil)
    end
  end
end
