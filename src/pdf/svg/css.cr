require "xml"

module PDF
  module SVG
    # Minimal CSS support for SVG `<style>` elements and `style=""` attributes.
    #
    # Supports type, universal, class, id and attribute selectors, joined by
    # descendant and child combinators. Selectors that use anything else
    # (pseudo-classes, sibling combinators, namespaces) never match.
    #
    # Ported in spirit from prawn-svg's CSS support.
    module CSS
      # One `property: value` pair.
      record Declaration, property : String, value : String, important : Bool = false

      # Specificity as {ids, classes + attributes, types}.
      alias Specificity = Tuple(Int32, Int32, Int32)

      IMPORTANT = /\s*!\s*important\s*\z/i
      COMMENT   = /\/\*.*?(?:\*\/|\z)/m
      HTML_TAG  = /<!--|-->/

      # Parses a declaration block body such as `fill: red; stroke: blue !important`.
      #
      # Each declaration is split on the first colon. Empty or malformed
      # declarations are skipped.
      def self.parse_declarations(text : String) : Array(Declaration)
        result = [] of Declaration
        text.split(';') do |piece|
          if declaration = parse_declaration(piece)
            result << declaration
          end
        end
        result
      end

      # Returns the specificity of `selector`, or nil if it is unsupported.
      def self.specificity(selector : String) : Specificity?
        Selector.parse(selector).try(&.specificity)
      end

      # :nodoc:
      def self.parse_declaration(piece : String) : Declaration?
        index = piece.index(':')
        return unless index

        property = piece[0, index].strip.downcase
        value = piece[(index + 1)..].strip
        important = !IMPORTANT.match(value).nil?
        value = value.sub(IMPORTANT, "").strip if important
        return if property.empty? || value.empty?

        Declaration.new(property, value, important)
      end

      # :nodoc:
      def self.element_parent(node : XML::Node) : XML::Node?
        parent = node.parent
        parent if parent && parent.element?
      end

      # :nodoc:
      record AttrSelector, name : String, op : Char?, value : String do
        def matches?(node : XML::Node) : Bool
          actual = node[name]?
          return false unless actual

          case op
          when '='
            actual == value
          when '~'
            actual.split.includes?(value)
          else
            true
          end
        end
      end

      # :nodoc:
      # A run of simple selectors with no combinator, such as `rect.a#b[c]`.
      class Compound
        property tag : String?
        property? touched = false
        getter ids = [] of String
        getter classes = [] of String
        getter attrs = [] of AttrSelector

        def matches?(node : XML::Node) : Bool
          return false if (name = @tag) && node.name != name
          return false unless @ids.all? { |id| node["id"]? == id }
          return false unless classes_match?(node)

          @attrs.all?(&.matches?(node))
        end

        def specificity : Specificity
          {@ids.size, @classes.size + @attrs.size, @tag ? 1 : 0}
        end

        private def classes_match?(node : XML::Node) : Bool
          return true if @classes.empty?

          present = (node["class"]? || "").split
          @classes.all? { |name| present.includes?(name) }
        end
      end

      # :nodoc:
      class Selector
        TOKEN = /\s*(>)\s*|\s+|(\*)|([A-Za-z_][\w-]*)|\.([\w-]+)|#([\w-]+)|\[\s*([\w-]+)\s*(?:(~?=)\s*(?:"([^"]*)"|'([^']*)'|([^\]\s]+))\s*)?\]/

        getter parts : Array(Compound)
        getter combinators : Array(Char)

        def initialize(@parts, @combinators)
        end

        # Parses one complex selector. Returns nil if it is unsupported.
        def self.parse(text : String) : Selector?
          text = text.strip
          return if text.empty?

          builder = Builder.new
          pos = 0
          while pos < text.size
            match = TOKEN.match(text, pos, Regex::MatchOptions::ANCHORED)
            return unless match && builder.feed(match)
            pos = match.end(0)
          end
          builder.finish
        end

        def specificity : Specificity
          ids = classes = types = 0
          @parts.each do |part|
            a, b, c = part.specificity
            ids += a
            classes += b
            types += c
          end
          {ids, classes, types}
        end

        # Failed {part index, node} pairs are remembered for one call, so
        # descendant combinators cost at most parts x depth checks instead
        # of growing exponentially with the number of combinators.
        def matches?(node : XML::Node) : Bool
          return @parts[0].matches?(node) if @parts.size == 1
          match_at(@parts.size - 1, node, Set(Tuple(Int32, UInt64)).new)
        end

        private def match_at(index : Int32, node : XML::Node, failed : Set(Tuple(Int32, UInt64))) : Bool
          key = {index, node.to_unsafe.address}
          return false if failed.includes?(key)

          matched = match_uncached(index, node, failed)
          failed << key unless matched
          matched
        end

        private def match_uncached(index : Int32, node : XML::Node, failed : Set(Tuple(Int32, UInt64))) : Bool
          return false unless @parts[index].matches?(node)
          return true if index == 0

          if @combinators[index - 1] == '>'
            parent = CSS.element_parent(node)
            !parent.nil? && match_at(index - 1, parent, failed)
          else
            ancestor_matches?(index - 1, node, failed)
          end
        end

        private def ancestor_matches?(index : Int32, node : XML::Node, failed : Set(Tuple(Int32, UInt64))) : Bool
          ancestor = CSS.element_parent(node)
          while ancestor
            return true if match_at(index, ancestor, failed)
            ancestor = CSS.element_parent(ancestor)
          end
          false
        end

        # Accumulates tokens into compounds and combinators.
        class Builder
          def initialize
            @parts = [] of Compound
            @combinators = [] of Char
            @current = Compound.new
          end

          # Consumes one token. Returns false if the token is not valid here.
          def feed(match : Regex::MatchData) : Bool
            if match[1]?
              combinator('>')
            elsif match[2]? || match[3]? || match[4]? || match[5]? || match[6]?
              simple(match)
            else
              combinator(' ')
            end
          end

          def finish : Selector?
            return unless @current.touched?
            @parts << @current
            Selector.new(@parts, @combinators)
          end

          private def combinator(char : Char) : Bool
            return false unless @current.touched?
            @parts << @current
            @combinators << char
            @current = Compound.new
            true
          end

          private def simple(match : Regex::MatchData) : Bool
            if tag = match[3]?
              return false if @current.touched?
              @current.tag = tag
            elsif match[2]?
              return false if @current.touched?
            elsif cls = match[4]?
              @current.classes << cls
            elsif id = match[5]?
              @current.ids << id
            else
              add_attribute(match)
            end
            @current.touched = true
          end

          private def add_attribute(match : Regex::MatchData) : Nil
            op = match[7]?.try { |text| text == "=" ? '=' : '~' }
            value = match[8]? || match[9]? || match[10]? || ""
            @current.attrs << AttrSelector.new(match[6], op, value)
          end
        end
      end

      # :nodoc:
      record Rule, selector : Selector, specificity : Specificity, order : Int32, declarations : Array(Declaration)

      # A collection of CSS rules gathered from `<style>` elements.
      class Stylesheet
        def initialize
          @rules = [] of Rule
          @order = 0
        end

        # Appends the rules from one CSS text. Source order keeps increasing
        # across calls. Malformed input is skipped and never raises.
        def add(css : String) : Nil
          text = css.gsub(COMMENT, "").gsub(HTML_TAG, "")
          pos = 0
          while pos < text.size
            pos = parse_next(text, pos)
          end
        end

        # Number of parsed (selector, block) rules.
        def rule_count : Int32
          @rules.size
        end

        # Returns the declarations of all rules that match `node`, ordered
        # ascending by (specificity, source order). `!important` flags are kept
        # but not used for ordering.
        def declarations_for(node : XML::Node) : Array(Declaration)
          matching = @rules.select(&.selector.matches?(node))
          matching.sort_by! { |rule| {rule.specificity, rule.order} }
          matching.flat_map(&.declarations)
        end

        # Parses one rule or at-rule starting at `pos`. Returns the next position.
        private def parse_next(text : String, pos : Int32) : Int32
          while pos < text.size && text[pos].whitespace?
            pos += 1
          end
          return text.size if pos >= text.size
          return skip_at_rule(text, pos) if text[pos] == '@'

          open = text.index('{', pos)
          return text.size unless open

          close = text.index('}', open) || text.size
          add_rule(text[pos...open], text[(open + 1)...close])
          close + 1
        end

        private def add_rule(prelude : String, body : String) : Nil
          declarations = CSS.parse_declarations(body)
          return if declarations.empty?

          prelude.split(',') do |source|
            selector = Selector.parse(source)
            next unless selector
            @rules << Rule.new(selector, selector.specificity, @order, declarations)
          end
          @order += 1
        end

        private def skip_at_rule(text : String, pos : Int32) : Int32
          semicolon = text.index(';', pos)
          brace = text.index('{', pos)
          if brace.nil? || (semicolon && semicolon < brace)
            return semicolon ? semicolon + 1 : text.size
          end

          skip_block(text, brace)
        end

        private def skip_block(text : String, start : Int32) : Int32
          depth = 0
          (start...text.size).each do |i|
            case text[i]
            when '{' then depth += 1
            when '}' then depth -= 1
            end
            return i + 1 if depth == 0
          end
          text.size
        end
      end
    end
  end
end
