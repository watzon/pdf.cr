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
        @width, @height = parse_dimensions
        @viewbox = parse_viewbox
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

      private def parse_dimensions : Tuple(Float64, Float64)
        w = parse_length(@root["width"]?) || 300.0
        h = parse_length(@root["height"]?) || 150.0
        {w, h}
      end

      private def parse_viewbox : Tuple(Float64, Float64, Float64, Float64)?
        vb = @root["viewBox"]?
        return nil unless vb

        parts = vb.strip.split(/[\s,]+/)
        return nil unless parts.size == 4

        {parts[0].to_f, parts[1].to_f, parts[2].to_f, parts[3].to_f}
      rescue
        nil
      end

      # Parses a CSS length value (e.g., "100px", "50%", "10em", "5cm").
      # Returns the value in user units (approximately points for PDF).
      def self.parse_length(value : String?, reference : Float64 = 0.0) : Float64?
        return nil unless value
        value = value.strip
        return nil if value.empty?

        if value.ends_with?("px")
          value.rchop("px").to_f?
        elsif value.ends_with?("pt")
          value.rchop("pt").to_f?
        elsif value.ends_with?("pc")
          v = value.rchop("pc").to_f?
          v ? v * 12.0 : nil
        elsif value.ends_with?("mm")
          v = value.rchop("mm").to_f?
          v ? v * 2.83465 : nil
        elsif value.ends_with?("cm")
          v = value.rchop("cm").to_f?
          v ? v * 28.3465 : nil
        elsif value.ends_with?("in")
          v = value.rchop("in").to_f?
          v ? v * 72.0 : nil
        elsif value.ends_with?("em")
          v = value.rchop("em").to_f?
          v ? v * 16.0 : nil # approximate
        elsif value.ends_with?("%")
          v = value.rchop("%").to_f?
          v ? v / 100.0 * reference : nil
        else
          value.to_f?
        end
      end

      private def parse_length(value : String?, reference : Float64 = 0.0) : Float64?
        Parser.parse_length(value, reference)
      end
    end
  end
end
