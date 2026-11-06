require "xml"

module PDF
  module SVG
    # A `linearGradient` or `radialGradient` paint server, resolved against
    # its `href` chain, and its conversion to PDF shading objects.
    #
    # Colors become an axial (type 2) or radial (type 3) shading with a
    # stitching function. Stops with an opacity below 1 add a DeviceGray
    # shading of the same geometry; the renderer uses it as a luminosity
    # soft mask. `spreadMethod` reflect and repeat are drawn as pad.
    class Gradient
      enum Kind
        Linear
        Radial
      end

      record Stop, offset : Float64, rgb : Tuple(Float64, Float64, Float64), opacity : Float64

      ATTRIBUTES = %w[x1 y1 x2 y2 cx cy r fx fy fr gradientUnits gradientTransform spreadMethod]

      getter kind : Kind
      getter stops : Array(Stop)

      # True when coordinates are fractions of the shape's bounding box.
      getter? bounding_box_units : Bool

      # Raw attribute values after `href` inheritance.
      getter attributes : Hash(String, String)

      def initialize(@kind : Kind, @stops : Array(Stop), @attributes : Hash(String, String))
        @bounding_box_units = @attributes["gradientUnits"]? != "userSpaceOnUse"
      end

      # Builds a gradient from its element. `lookup` resolves `href`
      # targets by id. `stop_style` returns {stop-color, stop-opacity}
      # for a stop element after the CSS cascade.
      def self.from_node(
        node : XML::Node,
        lookup : Proc(String, XML::Node?),
        stop_style : Proc(XML::Node, Tuple(String?, String?)),
      ) : Gradient?
        kind = node.name == "radialGradient" ? Kind::Radial : Kind::Linear
        attributes = {} of String => String
        stop_nodes = nil
        seen = Set(XML::Node).new
        current = node

        while current && seen.add?(current)
          inherit_attributes(attributes, current)
          stop_nodes ||= stop_elements(current)
          current = (href = current["href"]?) ? lookup.call(href.lchop('#')) : nil
        end

        new(kind, build_stops(stop_nodes || [] of XML::Node, stop_style), attributes)
      end

      # Copies attributes the gradient does not set yet from `node`.
      private def self.inherit_attributes(attributes : Hash(String, String), node : XML::Node) : Nil
        ATTRIBUTES.each do |name|
          next if attributes.has_key?(name)
          if value = node[name]?
            attributes[name] = value
          end
        end
      end

      private def self.stop_elements(node : XML::Node) : Array(XML::Node)?
        stops = node.children.select { |child| child.element? && child.name == "stop" }
        stops.empty? ? nil : stops
      end

      private def self.build_stops(nodes : Array(XML::Node), stop_style : Proc(XML::Node, Tuple(String?, String?))) : Array(Stop)
        last_offset = 0.0
        nodes.map do |stop|
          offset = parse_offset(stop["offset"]?).clamp(0.0, 1.0)
          offset = last_offset if offset < last_offset
          last_offset = offset

          color, opacity = stop_style.call(stop)
          rgba = Color.parse_rgba(color || "black") || {0.0, 0.0, 0.0, 1.0}
          alpha = (opacity.try(&.to_f?) || 1.0).clamp(0.0, 1.0) * rgba[3]
          Stop.new(offset, {rgba[0], rgba[1], rgba[2]}, alpha)
        end
      end

      private def self.parse_offset(value : String?) : Float64
        return 0.0 unless value
        value = value.strip
        return (value.rchop.to_f? || 0.0) / 100.0 if value.ends_with?('%')
        value.to_f? || 0.0
      end

      # True when any stop is not fully opaque.
      def translucent? : Bool
        @stops.any? { |stop| stop.opacity < 1.0 }
      end

      # Returns the matrix from gradient space to user space for a shape
      # with the given bounding box, or nil if the gradient cannot paint it
      # (objectBoundingBox units on a shape without area).
      def matrix(bbox : Geometry::Box) : Transform::Matrix?
        transform = Transform.parse(@attributes["gradientTransform"]?)
        return transform unless bounding_box_units?

        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        return if w <= 0 || h <= 0

        Transform.multiply({w, 0.0, 0.0, h, bbox[0], bbox[1]}, transform)
      end

      # Returns the shading coordinates in gradient space: {x1, y1, x2, y2}
      # for linear and {fx, fy, fr, cx, cy, r} for radial gradients, or nil
      # for a degenerate gradient that paints as its last stop color.
      def coords(viewport : Tuple(Float64, Float64)) : Array(Float64)?
        @kind.linear? ? linear_coords(viewport) : radial_coords(viewport)
      end

      private def linear_coords(viewport : Tuple(Float64, Float64)) : Array(Float64)?
        x1 = length("x1", "0%", viewport[0])
        y1 = length("y1", "0%", viewport[1])
        x2 = length("x2", "100%", viewport[0])
        y2 = length("y2", "0%", viewport[1])
        return if x1 == x2 && y1 == y2
        [x1, y1, x2, y2]
      end

      private def radial_coords(viewport : Tuple(Float64, Float64)) : Array(Float64)?
        diagonal = Math.sqrt(viewport[0] ** 2 + viewport[1] ** 2) / Math.sqrt(2.0)
        cx = length("cx", "50%", viewport[0])
        cy = length("cy", "50%", viewport[1])
        r = length("r", "50%", diagonal)
        return if r <= 0

        fx = @attributes.has_key?("fx") ? length("fx", "50%", viewport[0]) : cx
        fy = @attributes.has_key?("fy") ? length("fy", "50%", viewport[1]) : cy
        fr = length("fr", "0%", diagonal).clamp(0.0, r)
        fx, fy = clamp_focus(fx, fy, cx, cy, r)
        [fx, fy, fr, cx, cy, r]
      end

      # Keeps the focal point inside the end circle, as PDF requires for
      # a well-formed cone.
      private def clamp_focus(fx : Float64, fy : Float64, cx : Float64, cy : Float64, r : Float64) : Tuple(Float64, Float64)
        dx = fx - cx
        dy = fy - cy
        distance = Math.sqrt(dx * dx + dy * dy)
        limit = r * 0.999
        return {fx, fy} if distance <= limit

        {cx + dx * limit / distance, cy + dy * limit / distance}
      end

      # Resolves a coordinate attribute. In objectBoundingBox units a
      # percentage is a fraction; in user space it is relative to the
      # viewport size.
      private def length(name : String, default : String, reference : Float64) : Float64
        value = (@attributes[name]? || default).strip
        if value.ends_with?('%')
          fraction = (value.rchop.to_f? || 0.0) / 100.0
          return bounding_box_units? ? fraction : fraction * reference
        end
        Parser.parse_length(value, reference) || 0.0
      end

      # Builds the color shading dictionary for the given coordinates.
      def color_shading(coords : Array(Float64)) : Objects::Dictionary
        shading(coords, "DeviceRGB", @stops.map { |stop| [stop.rgb[0], stop.rgb[1], stop.rgb[2]] })
      end

      # Builds the DeviceGray opacity shading used as a soft mask.
      def alpha_shading(coords : Array(Float64)) : Objects::Dictionary
        shading(coords, "DeviceGray", @stops.map { |stop| [stop.opacity] })
      end

      private def shading(coords : Array(Float64), color_space : String, values : Array(Array(Float64))) : Objects::Dictionary
        dict = Objects::Dictionary.new
        dict["ShadingType"] = Objects::Number.new(@kind.linear? ? 2 : 3)
        dict["ColorSpace"] = Objects::Name.new(color_space)
        dict["Coords"] = Objects::Array.new(coords)
        dict["Function"] = function(values)
        dict["Extend"] = Objects::Array.new([Objects::Boolean.new(true), Objects::Boolean.new(true)] of Objects::Base)
        dict
      end

      # One exponential (type 2) function per stop interval, joined by a
      # stitching (type 3) function when there are several intervals.
      # Missing stops at offset 0 and 1 repeat the nearest stop.
      private def function(values : Array(Array(Float64))) : Objects::Dictionary
        offsets = @stops.map(&.offset)
        if offsets.first > 0
          offsets.unshift(0.0)
          values.unshift(values.first)
        end
        if offsets.last < 1
          offsets << 1.0
          values << values.last
        end

        # Zero-width intervals (hard color stops) become the jump between
        # their neighbours, so Bounds stay strictly increasing.
        pieces = [] of Objects::Dictionary
        ends = [] of Float64
        (0...offsets.size - 1).each do |i|
          next unless offsets[i + 1] > offsets[i]
          pieces << interpolation(values[i], values[i + 1])
          ends << offsets[i + 1]
        end
        return interpolation(values.last, values.last) if pieces.empty?
        return pieces.first if pieces.size == 1

        stitching(pieces, ends[0...-1])
      end

      private def interpolation(from : Array(Float64), to : Array(Float64)) : Objects::Dictionary
        dict = Objects::Dictionary.new
        dict["FunctionType"] = Objects::Number.new(2)
        dict["Domain"] = Objects::Array.new([0.0, 1.0])
        dict["C0"] = Objects::Array.new(from)
        dict["C1"] = Objects::Array.new(to)
        dict["N"] = Objects::Number.new(1)
        dict
      end

      private def stitching(pieces : Array(Objects::Dictionary), bounds : Array(Float64)) : Objects::Dictionary
        encode = [] of Float64
        pieces.size.times { encode << 0.0 << 1.0 }

        dict = Objects::Dictionary.new
        dict["FunctionType"] = Objects::Number.new(3)
        dict["Domain"] = Objects::Array.new([0.0, 1.0])
        dict["Functions"] = Objects::Array.new(pieces.map(&.as(Objects::Base)))
        dict["Bounds"] = Objects::Array.new(bounds)
        dict["Encode"] = Objects::Array.new(encode)
        dict
      end
    end
  end
end
