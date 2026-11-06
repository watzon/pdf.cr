require "xml"

module PDF
  module SVG
    # Parses an SVG document and extracts the document dimensions and
    # element tree. Uses Crystal's built-in XML parser.
    #
    # Ported from Prawn::SVG::Document.
    class Parser
      # The root SVG element
      getter root : XML::Node

      # Document width in user units
      getter width : Float64

      # Document height in user units
      getter height : Float64

      # ViewBox [min-x, min-y, width, height]
      getter viewbox : Tuple(Float64, Float64, Float64, Float64)?

      # Warnings generated during parsing
      getter warnings : Array(String) = [] of String

      def initialize(svg_data : String)
        doc = XML.parse(svg_data)
        @root = find_svg_root(doc)
        @viewbox = parse_viewbox
        @width, @height = parse_dimensions
      end

      # Returns all child elements of the SVG root.
      def elements : Array(XML::Node)
        children = [] of XML::Node
        @root.children.each do |child|
          children << child if child.element?
        end
        children
      end

      private def find_svg_root(doc : XML::Node) : XML::Node
        doc.children.each do |child|
          return child if child.element? && child.name == "svg"
        end
        # If the document itself is the svg element
        return doc if doc.name == "svg"
        raise ArgumentError.new("No <svg> root element found in SVG data")
      end

      # Percentages have no reference here, so they (and missing or
      # non-positive sizes) fall back to the viewBox size, then to the
      # SVG default of 300 x 150.
      private def parse_dimensions : Tuple(Float64, Float64)
        vb = @viewbox
        {dimension("width", vb.try(&.[2]) || 300.0), dimension("height", vb.try(&.[3]) || 150.0)}
      end

      private def dimension(name : String, fallback : Float64) : Float64
        value = @root[name]?
        return fallback if value.nil? || value.strip.ends_with?('%')
        length = parse_length(value)
        length && length > 0 ? length : fallback
      end

      private def parse_viewbox : Tuple(Float64, Float64, Float64, Float64)?
        vb = @root["viewBox"]?
        return unless vb

        parts = vb.strip.split(/[\s,]+/)
        return unless parts.size == 4

        numbers = parts.map(&.to_f)
        return unless numbers.all?(&.finite?)
        {numbers[0], numbers[1], numbers[2], numbers[3]}
      rescue
        nil
      end

      # Unit suffixes with their conversion to user units. Order matters
      # only for suffixes that end with each other (none do).
      LENGTH_UNITS = {
        "px" => ->(v : Float64, _ref : Float64) { v },
        "pt" => ->(v : Float64, _ref : Float64) { v },
        "pc" => ->(v : Float64, _ref : Float64) { v * 12.0 },
        "mm" => ->(v : Float64, _ref : Float64) { v * 2.83465 },
        "cm" => ->(v : Float64, _ref : Float64) { v * 28.3465 },
        "in" => ->(v : Float64, _ref : Float64) { v * 72.0 },
        "em" => ->(v : Float64, _ref : Float64) { v * 16.0 }, # approximate
        "%"  => ->(v : Float64, ref : Float64) { v / 100.0 * ref },
      }

      # Parses a CSS length value (e.g., "100px", "50%", "10em", "5cm").
      # Returns the value in user units (approximately points for PDF).
      def self.parse_length(value : String?, reference : Float64 = 0.0) : Float64?
        return unless value
        value = value.strip
        return if value.empty?

        unit, factor = LENGTH_UNITS.find { |suffix, _| value.ends_with?(suffix) } || return value.to_f?.try { |number| number if number.finite? }
        number = value.rchop(unit).to_f?
        number && number.finite? ? factor.call(number, reference) : nil
      end

      private def parse_length(value : String?, reference : Float64 = 0.0) : Float64?
        Parser.parse_length(value, reference)
      end
    end
  end
end
