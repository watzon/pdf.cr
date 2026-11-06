module PDF
  module SVG
    # The computed presentation style of one element.
    #
    # Inherited properties (fill, stroke, fonts, ...) are copied from the
    # parent and overridden by the element's declarations. `opacity` does
    # not inherit as a value; instead the renderer multiplies it into the
    # fill and stroke opacity of everything inside the element. This is an
    # approximation of group opacity: overlapping children blend with each
    # other instead of as one flattened group.
    class Style
      # Properties that inherit from ancestors.
      INHERITED = %w[
        fill fill-opacity fill-rule stroke stroke-width stroke-opacity
        stroke-dasharray stroke-dashoffset stroke-linecap stroke-linejoin
        stroke-miterlimit font-family font-size font-weight font-style
        text-anchor visibility color clip-rule
      ]

      # Properties that apply to one element only.
      NON_INHERITED = %w[opacity clip-path display overflow stop-color stop-opacity]

      # Every property read from presentation attributes and CSS.
      PROPERTIES = INHERITED + NON_INHERITED

      # Font size used when no element sets one, in user units.
      DEFAULT_FONT_SIZE = 12.0

      # Inherited property values.
      getter values : Hash(String, String)

      # Declared values of non-inherited properties on this element.
      getter own : Hash(String, String)

      # Product of the `opacity` of this element and all its ancestors.
      getter opacity : Float64

      def initialize(@values = {} of String => String, @own = {} of String => String, @opacity = 1.0)
      end

      # Returns the inherited property value, if any element set it.
      def [](name : String) : String?
        @values[name]?
      end

      # The computed font size in user units.
      def font_size : Float64
        @values["font-size"]?.try(&.to_f?) || DEFAULT_FONT_SIZE
      end

      def display_none? : Bool
        @own["display"]? == "none"
      end

      def hidden? : Bool
        visibility = @values["visibility"]?
        visibility == "hidden" || visibility == "collapse"
      end

      # Builds the style of a child element from its declared properties.
      def derive(declared : Hash(String, String)) : Style
        values = @values.dup
        own = {} of String => String
        declared.each do |name, value|
          next if value == "inherit"
          if INHERITED.includes?(name)
            values[name] = name == "font-size" ? resolve_font_size(value) : value
          else
            own[name] = value
          end
        end

        own_opacity = own["opacity"]?.try { |v| Style.parse_fraction(v) } || 1.0
        Style.new(values, own, @opacity * own_opacity)
      end

      # Resolves em and % sizes against the parent font size.
      private def resolve_font_size(value : String) : String
        value = value.strip
        size = if value.ends_with?("em")
                 value.rchop("em").to_f?.try(&.*(font_size))
               elsif value.ends_with?('%')
                 value.rchop.to_f?.try { |pct| pct / 100.0 * font_size }
               else
                 Parser.parse_length(value)
               end
        (size || font_size).to_s
      end

      # Parses a number or percentage into the range 0..1.
      def self.parse_fraction(value : String) : Float64?
        value = value.strip
        number = value.ends_with?('%') ? value.rchop.to_f?.try(&./(100.0)) : value.to_f?
        number.try(&.clamp(0.0, 1.0))
      end
    end
  end
end
