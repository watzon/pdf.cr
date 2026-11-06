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
      # | `<font name="Courier" size="10">` | font name and/or size |
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
          position = 0

          while match = TAG_PATTERN.match(markup, position)
            text << markup[position...match.begin(0)]
            position = match.end(0)
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
          text << markup[position..]
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
            size = attrs["size"]?.try do |value|
              value.to_f? || raise ArgumentError.new("Invalid font size in markup: #{value.inspect}")
            end
            OpenTag.new(name, nil, nil, attrs["name"]?, size)
          else
            OpenTag.new(name, STYLE_TAGS[name], nil, nil, nil)
          end
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
