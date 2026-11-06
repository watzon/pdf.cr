require "xml"

module PDF
  module SVG
    # Renders an SVG document onto a PDF page.
    #
    # The renderer emits one root `q ... cm ... Q` block that maps SVG user
    # space (origin top-left, y down) to the page: translate(at) *
    # scale(sx, -sy) * translate(-min_x, -min_y), as given by the root
    # viewBox and preserveAspectRatio. The output box clips the drawing.
    # Shapes are then drawn in raw SVG user coordinates.
    #
    # Supported:
    # - Shapes: rect (with rx/ry), circle, ellipse, line, polyline, polygon,
    #   path (including arcs).
    # - Structure: g, a, switch, defs, use (with x/y, symbol and svg
    #   targets), nested svg viewports, symbol, the transform attribute and
    #   preserveAspectRatio (alignments with meet or slice, and none).
    # - Styling: presentation attributes, style="", `<style>` sheets with
    #   type, class, id and attribute selectors (by specificity, with
    #   !important), inheritance and `inherit`, currentColor.
    # - Paint: colors (named, hex, rgb(a)), fill-rule, linearGradient and
    #   radialGradient (stop-opacity through a soft mask), opacity,
    #   fill-opacity and stroke-opacity, stroke-width, stroke-dasharray,
    #   stroke-dashoffset, stroke-linecap, stroke-linejoin and
    #   stroke-miterlimit.
    # - clipPath (userSpaceOnUse and objectBoundingBox, clip-rule).
    # - Text: text and tspan with x, y, dx and dy (lists per character),
    #   text-anchor, font-family (mapped to the standard 14 fonts),
    #   font-size, font-weight and font-style.
    #
    # Limits: group opacity is applied per shape (see `Style`); gradient
    # strokes and gradient text use shading patterns, whose matrix assumes
    # the page has its default transformation when `Page#svg` is called;
    # spreadMethod reflect and repeat draw as pad; text is not stroked.
    # Elements such as image, mask, pattern, marker and filter are skipped
    # with a warning.
    #
    # Ported from Prawn::SVG::Renderer.
    class Renderer
      # Elements that never draw by themselves.
      NON_RENDERING = Set{
        "defs", "title", "desc", "metadata", "style", "script", "symbol",
        "linearGradient", "radialGradient", "clipPath", "stop",
      }

      # Elements that draw nothing and get a warning.
      UNSUPPORTED = Set{"image", "mask", "pattern", "marker", "filter", "foreignObject", "textPath"}

      # Shape elements and their geometry builders.
      SHAPES = Set{"rect", "circle", "ellipse", "line", "polyline", "polygon", "path"}

      # Upper bound on nested `use` references (guards against cycles).
      MAX_USE_DEPTH = 32

      # The PDF page to draw on
      getter page : Page

      # The parsed SVG document
      getter parser : Parser

      # Position of the top-left corner of the SVG in PDF coordinates
      getter x : Float64
      getter y : Float64

      # Output dimensions
      getter output_width : Float64
      getter output_height : Float64

      # Scale from SVG user units to points
      getter x_scale : Float64
      getter y_scale : Float64

      # Warnings generated during rendering
      getter warnings : Array(String) = [] of String

      @root_matrix : Transform::Matrix
      @root_viewport : Tuple(Float64, Float64)
      @ids = {} of String => XML::Node
      @stylesheet = CSS::Stylesheet.new
      @ctm : Transform::Matrix = Transform::IDENTITY
      @ctm_stack = [] of Transform::Matrix
      @viewports = [] of Tuple(Float64, Float64)
      @use_stack = [] of XML::Node

      def initialize(
        @page : Page,
        @parser : Parser,
        *,
        x : Float64 = 0.0,
        y : Float64 = 0.0,
        width : Float64? = nil,
        height : Float64? = nil,
      )
        @x = x
        @y = y

        viewbox = parser.viewbox
        viewbox = nil if viewbox && (viewbox[2] <= 0 || viewbox[3] <= 0)
        box = viewbox || {0.0, 0.0, parser.width, parser.height}
        svg_w = box[2]
        svg_h = box[3]

        if width && height
          @output_width = width
          @output_height = height
        elsif width
          @output_width = width
          @output_height = width * svg_h / svg_w
        elsif height
          @output_height = height
          @output_width = height * svg_w / svg_h
        else
          @output_width = parser.width
          @output_height = parser.height
        end

        # preserveAspectRatio only applies with a viewBox; without one the
        # default xMidYMid meet keeps the drawing undistorted.
        aspect = viewbox ? AspectRatio.parse(parser.root["preserveAspectRatio"]?) : AspectRatio.new
        sx, _, _, sy, tx, ty = aspect.transform(box, 0.0, 0.0, @output_width, @output_height)
        @x_scale = sx
        @y_scale = sy
        @root_matrix = {sx, 0.0, 0.0, -sy, @x + tx, @y - ty}
        @root_viewport = {svg_w, svg_h}

        index_document(parser.root)
      end

      # Draws the SVG onto the PDF page.
      def draw : Nil
        save
        page.rectangle(@x, @y - @output_height, @output_width, @output_height)
        page.clip!
        concat(@root_matrix)
        @viewports << @root_viewport
        style = Style.new.derive(declared(parser.root))
        parser.elements.each { |element| render_element(element, style) }
        @viewports.pop
        restore
      end

      # Records ids for href and url() lookups, and gathers `<style>` rules
      # in document order.
      private def index_document(node : XML::Node) : Nil
        return unless node.element?

        if id = node["id"]?
          @ids[id] ||= node
        end
        @stylesheet.add(node.content) if node.name == "style"
        node.children.each { |child| index_document(child) }
      end

      private def render_element(node : XML::Node, inherited : Style) : Nil
        return unless node.element?

        tag = node.name
        return if NON_RENDERING.includes?(tag)
        if UNSUPPORTED.includes?(tag)
          warn("Unsupported SVG element: #{tag}")
          return
        end

        style = inherited.derive(declared(node))
        return if style.display_none?

        save
        apply_transform(node["transform"]?)
        apply_clip_path(node, style)
        render_content(node, tag, style)
        restore
      end

      private def render_content(node : XML::Node, tag : String, style : Style) : Nil
        if SHAPES.includes?(tag)
          commands = shape_geometry(node)
          paint_shape(commands, style, closed_fill: tag != "line") if commands
        elsif tag == "text"
          draw_text(node, style)
        elsif tag == "use"
          render_use(node, style)
        elsif tag == "svg"
          render_nested_svg(node, style)
        elsif tag == "switch"
          first = node.children.find { |child| switch_candidate?(child) }
          render_element(first, style) if first
        else
          # g, a and unknown containers: draw children
          node.children.each { |child| render_element(child, style) }
        end
      end

      # A switch draws its first child that this renderer can draw.
      private def switch_candidate?(node : XML::Node) : Bool
        return false unless node.element?
        return false if NON_RENDERING.includes?(node.name) || UNSUPPORTED.includes?(node.name)
        node["requiredExtensions"]?.nil?
      end

      # -- Structure ---------------------------------------------------------

      private def render_use(node : XML::Node, style : Style) : Nil
        target = href_target(node)
        return unless target
        return if @use_stack.includes?(target) || @use_stack.size >= MAX_USE_DEPTH

        @use_stack << target
        tx = length(node["x"]?, :x)
        ty = length(node["y"]?, :y)
        concat({1.0, 0.0, 0.0, 1.0, tx, ty}) unless tx == 0 && ty == 0

        case target.name
        when "symbol", "svg"
          render_used_viewport(node, target, style)
        else
          render_element(target, style)
        end
        @use_stack.pop
      end

      # A symbol or svg referenced by `use`: the use width and height
      # override the target's, and both default to 100%.
      private def render_used_viewport(use : XML::Node, target : XML::Node, inherited : Style) : Nil
        style = inherited.derive(declared(target))
        return if style.display_none?

        width = length(use["width"]? || target["width"]? || "100%", :x)
        height = length(use["height"]? || target["height"]? || "100%", :y)
        x = y = 0.0
        save
        if target.name == "svg"
          apply_transform(target["transform"]?)
          x = length(target["x"]?, :x)
          y = length(target["y"]?, :y)
        end
        render_viewport(target, style, x, y, width, height)
        restore
      end

      private def render_nested_svg(node : XML::Node, style : Style) : Nil
        x = length(node["x"]?, :x)
        y = length(node["y"]?, :y)
        width = length(node["width"]? || "100%", :x)
        height = length(node["height"]? || "100%", :y)
        render_viewport(node, style, x, y, width, height)
      end

      # Establishes a new viewport at (x, y) with the given size, maps the
      # element's viewBox into it and draws the children.
      private def render_viewport(node : XML::Node, style : Style, x : Float64, y : Float64, width : Float64, height : Float64) : Nil
        return if width <= 0 || height <= 0

        unless {"visible", "auto"}.includes?(style.own["overflow"]?)
          page.rectangle(x, y, width, height)
          page.clip!
        end

        viewport = {width, height}
        if viewbox = parse_viewbox(node["viewBox"]?)
          concat(AspectRatio.parse(node["preserveAspectRatio"]?).transform(viewbox, x, y, width, height))
          viewport = {viewbox[2], viewbox[3]}
        elsif x != 0 || y != 0
          concat({1.0, 0.0, 0.0, 1.0, x, y})
        end

        @viewports << viewport
        node.children.each { |child| render_element(child, style) }
        @viewports.pop
      end

      private def parse_viewbox(value : String?) : Tuple(Float64, Float64, Float64, Float64)?
        return unless value
        parts = value.strip.split(/[\s,]+/).compact_map(&.to_f?)
        return unless parts.size == 4 && parts[2] > 0 && parts[3] > 0
        {parts[0], parts[1], parts[2], parts[3]}
      end

      private def href_target(node : XML::Node) : XML::Node?
        href = node["href"]?
        return unless href && href.starts_with?('#')
        @ids[href.lchop('#')]?
      end

      # Returns the element referenced by a `url(#id)` paint or clip value.
      private def url_target(value : String?) : XML::Node?
        return unless value
        match = value.match(/\Aurl\(\s*['"]?#([^'")\s]+)['"]?\s*\)/)
        match ? @ids[match[1]]? : nil
      end

      # -- Styling -----------------------------------------------------------

      # Collects the element's declared properties in cascade order:
      # presentation attributes, then style sheet rules by specificity,
      # then style="", then !important rules and !important inline values.
      private def declared(node : XML::Node) : Hash(String, String)
        result = {} of String => String
        Style::PROPERTIES.each do |name|
          if value = node[name]?
            result[name] = value.strip
          end
        end

        sheet = @stylesheet.declarations_for(node)
        inline = node["style"]?.try { |text| CSS.parse_declarations(text) } || [] of CSS::Declaration
        {false, true}.each do |important|
          {sheet, inline}.each do |declarations|
            declarations.each { |decl| result[decl.property] = decl.value if decl.important == important }
          end
        end
        result
      end

      # -- Geometry ----------------------------------------------------------

      private def shape_geometry(node : XML::Node) : Array(PathCommand)?
        case node.name
        when "rect"     then rect_geometry(node)
        when "circle"   then circle_geometry(node)
        when "ellipse"  then ellipse_geometry(node)
        when "line"     then line_geometry(node)
        when "polyline" then points_geometry(node, closed: false)
        when "polygon"  then points_geometry(node, closed: true)
        when "path"     then path_geometry(node)
        end
      end

      private def rect_geometry(node : XML::Node) : Array(PathCommand)?
        w = length(node["width"]?, :x)
        h = length(node["height"]?, :y)
        return if w <= 0 || h <= 0

        rx_attr = node["rx"]?.try { |v| length(v, :x) }
        ry_attr = node["ry"]?.try { |v| length(v, :y) }
        rx = (rx_attr || ry_attr || 0.0).clamp(0.0, w / 2.0)
        ry = (ry_attr || rx_attr || 0.0).clamp(0.0, h / 2.0)
        Geometry.rect(length(node["x"]?, :x), length(node["y"]?, :y), w, h, rx, ry)
      end

      private def circle_geometry(node : XML::Node) : Array(PathCommand)?
        r = length(node["r"]?, :other)
        return if r <= 0
        Geometry.ellipse(length(node["cx"]?, :x), length(node["cy"]?, :y), r, r)
      end

      private def ellipse_geometry(node : XML::Node) : Array(PathCommand)?
        rx = length(node["rx"]?, :x)
        ry = length(node["ry"]?, :y)
        return if rx <= 0 || ry <= 0
        Geometry.ellipse(length(node["cx"]?, :x), length(node["cy"]?, :y), rx, ry)
      end

      private def line_geometry(node : XML::Node) : Array(PathCommand)
        Geometry.polyline([
          {length(node["x1"]?, :x), length(node["y1"]?, :y)},
          {length(node["x2"]?, :x), length(node["y2"]?, :y)},
        ])
      end

      private def points_geometry(node : XML::Node, closed : Bool) : Array(PathCommand)?
        points = parse_points(node["points"]?)
        return if points.size < (closed ? 3 : 2)
        closed ? Geometry.polygon(points) : Geometry.polyline(points)
      end

      private def path_geometry(node : XML::Node) : Array(PathCommand)?
        d = node["d"]?
        return unless d
        commands = PathParser.parse(d)
        commands.empty? ? nil : commands
      end

      # Returns the outline of an element and its descendants, including
      # the element's own transform, in the space given by `matrix` (used
      # for clip paths).
      private def outline(node : XML::Node, matrix : Transform::Matrix, depth : Int32 = 0) : Array(PathCommand)
        return [] of PathCommand unless node.element? && depth < MAX_USE_DEPTH
        return [] of PathCommand if declared(node)["display"]? == "none"

        content_outline(node, Transform.multiply(matrix, Transform.parse(node["transform"]?)), depth)
      end

      # Returns the outline of an element in its own user space (its
      # transform attribute excluded), mapped by `matrix`.
      private def content_outline(node : XML::Node, matrix : Transform::Matrix, depth : Int32 = 0) : Array(PathCommand)
        result = [] of PathCommand
        if SHAPES.includes?(node.name)
          (commands = shape_geometry(node)) && result.concat(Geometry.transform(commands, matrix))
        elsif node.name == "use"
          target = href_target(node)
          offset = {1.0, 0.0, 0.0, 1.0, length(node["x"]?, :x), length(node["y"]?, :y)}
          result.concat(outline(target, Transform.multiply(matrix, offset), depth + 1)) if target
        elsif {"g", "a", "switch", "clipPath"}.includes?(node.name)
          node.children.each { |child| result.concat(outline(child, matrix, depth + 1)) }
        end
        result
      end

      # -- Clipping ----------------------------------------------------------

      private def apply_clip_path(node : XML::Node, style : Style) : Nil
        clip = url_target(style.own["clip-path"]?)
        return unless clip && clip.name == "clipPath"

        matrix = Transform::IDENTITY
        if clip["clipPathUnits"]? == "objectBoundingBox"
          box = Geometry.bbox(content_outline(node, Transform::IDENTITY))
          return clip_everything unless box && box[2] > box[0] && box[3] > box[1]
          matrix = {box[2] - box[0], 0.0, 0.0, box[3] - box[1], box[0], box[1]}
        end

        children = clip_children(clip, matrix)
        return clip_everything if children.empty?

        if children.size == 1
          Geometry.emit(page, children.first[0])
          children.first[1] ? page.clip_even_odd! : page.clip!
        else
          # The clip region is the union of the children: wind them all
          # the same way and use the nonzero rule.
          children.each { |child| Geometry.emit(page, Geometry.orient_positive(child[0])) }
          page.clip!
        end
      end

      # Returns the outline of each clipPath child, with whether its
      # clip-rule is evenodd.
      private def clip_children(clip : XML::Node, matrix : Transform::Matrix) : Array(Tuple(Array(PathCommand), Bool))
        clip_style = Style.new.derive(declared(clip))
        m = Transform.multiply(matrix, Transform.parse(clip["transform"]?))
        result = [] of Tuple(Array(PathCommand), Bool)
        clip.children.each do |child|
          commands = outline(child, m)
          next if commands.empty?
          rule = clip_style.derive(declared(child))["clip-rule"]
          result << {commands, rule == "evenodd"}
        end
        result
      end

      private def clip_everything : Nil
        page.rectangle(0, 0, 0, 0)
        page.clip!
      end

      # -- Graphics state ----------------------------------------------------

      private def save : Nil
        @ctm_stack << @ctm
        page.save_graphics_state
      end

      private def restore : Nil
        @ctm = @ctm_stack.pop
        page.restore_graphics_state
      end

      # Concatenates a matrix to the current transformation, tracking the
      # result so that shading patterns can be placed in page space.
      private def concat(matrix : Transform::Matrix) : Nil
        @ctm = Transform.multiply(@ctm, matrix)
        page.transform(*matrix)
      end

      private def apply_transform(transform_str : String?) : Nil
        return unless transform_str
        matrix = Transform.parse(transform_str)
        return if matrix == Transform::IDENTITY
        concat(matrix)
      end

      # -- Lengths -----------------------------------------------------------

      # Resolves a length attribute; percentages refer to the current
      # viewport width (:x), height (:y) or normalized diagonal (:other).
      # `em` and `ex` use `font_size` when given.
      private def length(value : String?, axis : Symbol, font_size : Float64? = nil) : Float64
        if font_size && value
          stripped = value.strip
          if stripped.ends_with?("em") || stripped.ends_with?("ex")
            number = stripped[0...-2].to_f?
            factor = stripped.ends_with?("em") ? font_size : font_size / 2.0
            return number && number.finite? ? number * factor : 0.0
          end
        end
        Parser.parse_length(value, viewport_reference(axis)) || 0.0
      end

      private def viewport_reference(axis : Symbol) : Float64
        w, h = @viewports.last? || @root_viewport
        case axis
        when :x then w
        when :y then h
        else         Math.sqrt(w * w + h * h) / Math.sqrt(2.0)
        end
      end

      private def parse_points(value : String?) : Array(Tuple(Float64, Float64))
        return [] of Tuple(Float64, Float64) unless value
        numbers = value.strip.split(/[\s,]+/).compact_map(&.to_f?)
        numbers.each_slice(2).select(&.size.==(2)).map { |pair| {pair[0], pair[1]} }.to_a
      end

      private def warn(message : String) : Nil
        @warnings << message unless @warnings.includes?(message)
      end
    end
  end
end
