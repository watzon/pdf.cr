module PDF
  module Text
    module Formatted
      # Converts a string with simple inline markup into formatted text
      # fragments for `Box` and `Page#formatted_text_box`.
      #
      # Ported from Prawn::Text::Formatted::Parser. Supported tags:
      #
      # | Tag | Effect |
      # |-----|--------|
      # | `<b>`, `<strong>` | `:bold` |
      # | `<i>`, `<em>` | `:italic` |
      # | `<u>` | `:underline` |
      # | `<strikethrough>` | `:strikethrough` |
      # | `<sub>`, `<sup>` | `:subscript`, `:superscript` |
      # | `<color rgb="FF0000">` | text color (`RGB` or `RRGGBB`, optional `#`) |
      # | `<font name="Courier" size="10">` | font name and/or size (a positive number) |
      # | `<br>`, `<br/>` | line break |
      #
      # Tags can nest. The entities `&lt;`, `&gt;` and `&amp;` produce `<`,
      # `>` and `&`. Text that looks like a tag but has an unknown name, and
      # a closing tag without a matching opening tag, stay as literal text. An
      # opening tag without a closing tag applies to the end of the string.
      #
      # ```
      # Parser.format("Hello <b>bold <i>world</i></b>!")
      # # => [{text: "Hello ", styles: []},
      # #     {text: "bold ", styles: [:bold]},
      # #     {text: "world", styles: [:bold, :italic]},
      # #     {text: "!", styles: []}]
      # ```
      module Parser
        STYLE_TAGS = {
          "b"             => :bold,
          "strong"        => :bold,
          "i"             => :italic,
          "em"            => :italic,
          "u"             => :underline,
          "strikethrough" => :strikethrough,
          "sub"           => :subscript,
          "sup"           => :superscript,
        }

        TAG_PATTERN = /<(\/?)([a-zA-Z]+)((?:\s+[a-zA-Z_-]+\s*=\s*(?:"[^"]*"|'[^']*'))*)\s*(\/?)>/

        ATTRIBUTE_PATTERN = /([a-zA-Z_-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/

        ENTITIES = {"&lt;" => "<", "&gt;" => ">", "&amp;" => "&"}

        # An open tag: its name and the format it sets.
        private record OpenTag, name : String, style : Symbol?, color : String?,
          font : String?, size : Float64?

        # Parses the markup and returns one fragment per run of text with
        # the same format.
        def self.format(markup : String) : Array(FragmentHash)
          fragments = [] of FragmentHash
          stack = [] of OpenTag
          text = IO::Memory.new
          bytes = markup.to_slice
          # Keep the scan linear in the size of the markup: use byte offsets
          # (char offsets in a non-ASCII string count from the start), and
          # check the UTF-8 encoding only in the first match (PCRE2 checks
          # the whole string in each match). Invalid UTF-8 still raises.
          position = 0
          match_options = Regex::MatchOptions::None

          while match = TAG_PATTERN.match_at_byte_index(markup, position, match_options)
            match_options = Regex::MatchOptions::NO_UTF_CHECK
            text.write(bytes[position, match.byte_begin(0) - position])
            position = match.byte_end(0)
            closing, name, attributes, self_closing = match[1], match[2].downcase, match[3], match[4]

            if name == "br" && closing.empty?
              text << '\n'
            elsif !known_tag?(name)
              text << match[0]
            elsif !closing.empty?
              index = stack.rindex { |tag| tag.name == name }
              if index
                flush(fragments, text, stack)
                stack.delete_at(index)
              else
                text << match[0]
              end
            elsif self_closing.empty?
              flush(fragments, text, stack)
              stack << open_tag(name, attributes)
            end
          end
          text.write(bytes[position..])
          flush(fragments, text, stack)
          fragments
        end

        private def self.known_tag?(name : String) : Bool
          STYLE_TAGS.has_key?(name) || name == "color" || name == "font"
        end

        private def self.open_tag(name : String, attributes : String) : OpenTag
          attrs = {} of String => String
          attributes.scan(ATTRIBUTE_PATTERN) do |attr|
            attrs[attr[1].downcase] = attr[2]? || attr[3]? || ""
          end

          case name
          when "color"
            OpenTag.new(name, nil, attrs["rgb"]?, nil, nil)
          when "font"
            size = attrs["size"]?.try { |value| parse_size(value) }
            OpenTag.new(name, nil, nil, attrs["name"]?, size)
          else
            OpenTag.new(name, STYLE_TAGS[name], nil, nil, nil)
          end
        end

        # A font size must be a positive, finite number. Other values (for
        # example `nan`, `inf`, `0` or `-5`) would write invalid numbers to
        # the content stream or break the line layout.
        private def self.parse_size(value : String) : Float64
          size = value.to_f?
          unless size && size.finite? && size > 0
            raise ArgumentError.new("Invalid font size in markup: #{value.inspect}. Use a positive number.")
          end
          size
        end

        # Adds the buffered text as a fragment with the format of the open
        # tags, then clears the buffer.
        private def self.flush(fragments : Array(FragmentHash), text : IO::Memory, stack : Array(OpenTag)) : Nil
          content = decode_entities(text.to_s)
          text.clear
          return if content.empty?

          hash = FragmentHash.new
          hash[:text] = content
          hash[:styles] = stack.compact_map(&.style).uniq!
          stack.reverse_each do |tag|
            if (color = tag.color) && !hash.has_key?(:color)
              hash[:color] = color
            end
            if (font = tag.font) && !hash.has_key?(:font)
              hash[:font] = font
            end
            if (size = tag.size) && !hash.has_key?(:size)
              hash[:size] = size
            end
          end
          fragments << hash
        end

        private def self.decode_entities(text : String) : String
          text.gsub(/&(?:lt|gt|amp);/) { |entity| ENTITIES[entity] }
        end
      end
    end
  end
end
