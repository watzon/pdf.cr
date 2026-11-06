require "xml"

module PDF
  module SVG
    # Renders an SVG document onto a PDF page.
    #
    # The renderer emits one root `q ... cm ... Q` block that maps SVG user
    # space (origin top-left, y down) to the page: translate(at) *
    # scale(s, -s) * translate(-min_x, -min_y). Shapes are then drawn in raw
    # SVG user coordinates. The viewBox is honoured with
    # preserveAspectRatio="xMidYMid meet" (uniform scale, centred).
    #
    # Supported: svg, g, rect, circle, ellipse, line, polyline, polygon, path
    # (including arcs), and text (Helvetica, x/y and font-size only); the
    # transform attribute; fill, stroke and stroke-width (as attributes or
    # in style="") with inheritance from ancestors.
    #
    # Not supported: use, CSS style sheets and classes, gradients, clipPath,
    # opacity, rect rx/ry, tspan, text-anchor, font-family, dash, cap and
    # join properties, and nested svg viewports.
    #
    # Ported from Prawn::SVG::Renderer.
    class Renderer
      # Presentation properties that inherit from ancestor elements.
      private record Style,
        fill : String? = nil,
        stroke : String? = nil,
        stroke_width : Float64? = nil do
        # Fill defaults to black.
        def fills? : Bool
          fill != "none"
        end

        # Stroke defaults to none.
        def strokes? : Bool
          !stroke.nil? && stroke != "none"
        end
      end

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

      # Uniform scale from SVG user units to points
      getter x_scale : Float64
      getter y_scale : Float64

      # Warnings generated during rendering
      getter warnings : Array(String) = [] of String

      @min_x : Float64
      @min_y : Float64
      @offset_x : Float64
      @offset_y : Float64

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

        # Size of the SVG user space that is mapped to the output box.
        svg_w = parser.width
        svg_h = parser.height
        @min_x = 0.0
        @min_y = 0.0

        if vb = parser.viewbox
          @min_x = vb[0]
          @min_y = vb[1]
          svg_w = vb[2] if vb[2] > 0
          svg_h = vb[3] if vb[3] > 0
        end

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

        # preserveAspectRatio xMidYMid meet
        scale = {@output_width / svg_w, @output_height / svg_h}.min
        @x_scale = scale
        @y_scale = scale
        @offset_x = (@output_width - svg_w * scale) / 2.0
        @offset_y = (@output_height - svg_h * scale) / 2.0
      end

      # Draws the SVG onto the PDF page.
      def draw : Nil
        page.save_graphics_state
        page.transform(
          @x_scale, 0.0, 0.0, -@y_scale,
          @x + @offset_x - @min_x * @x_scale,
          @y - @offset_y + @min_y * @y_scale,
        )
        style = resolve_style(parser.root, Style.new)
        parser.elements.each do |element|
          render_element(element, style)
        end
        page.restore_graphics_state
      end

      private def render_element(node : XML::Node, inherited : Style) : Nil
        return unless node.element?

        tag = node.name.downcase

        case tag
        when "defs", "title", "desc", "metadata", "style"
          return
        end

        style = resolve_style(node, inherited)

        # Element-level transforms apply to every renderable branch.
        page.save_graphics_state
        apply_transform(node["transform"]?)

        case tag
        when "rect"
          draw_rect(node, style)
        when "circle"
          draw_circle(node, style)
        when "ellipse"
          draw_ellipse(node, style)
        when "line"
          draw_line(node, style)
        when "polyline"
          draw_polyline(node, style)
        when "polygon"
          draw_polygon(node, style)
        when "path"
          draw_path(node, style)
        when "text"
          draw_text(node, style)
        else
          # g, nested svg and unknown containers: draw children
          node.children.each { |child| render_element(child, style) }
        end

        page.restore_graphics_state
      end

      private def resolve_style(node : XML::Node, inherited : Style) : Style
        sw = get_style(node, "stroke-width")
        Style.new(
          fill: get_style(node, "fill") || inherited.fill,
          stroke: get_style(node, "stroke") || inherited.stroke,
          stroke_width: (sw ? parse_coord(sw) : nil) || inherited.stroke_width,
        )
      end

      private def draw_rect(node : XML::Node, style : Style) : Nil
        x = parse_coord(node["x"]?) || 0.0
        y = parse_coord(node["y"]?) || 0.0
        w = parse_coord(node["width"]?) || 0.0
        h = parse_coord(node["height"]?) || 0.0
        return if w <= 0 || h <= 0

        apply_style(style)
        page.rectangle(x, y, w, h)
        paint(style)
      end

      private def draw_circle(node : XML::Node, style : Style) : Nil
        cx = parse_coord(node["cx"]?) || 0.0
        cy = parse_coord(node["cy"]?) || 0.0
        r = parse_coord(node["r"]?) || 0.0
        return if r <= 0

        apply_style(style)
        draw_ellipse_path(cx, cy, r, r)
        paint(style)
      end

      private def draw_ellipse(node : XML::Node, style : Style) : Nil
        cx = parse_coord(node["cx"]?) || 0.0
        cy = parse_coord(node["cy"]?) || 0.0
        rx = parse_coord(node["rx"]?) || 0.0
        ry = parse_coord(node["ry"]?) || 0.0
        return if rx <= 0 || ry <= 0

        apply_style(style)
        draw_ellipse_path(cx, cy, rx, ry)
        paint(style)
      end

      private def draw_ellipse_path(cx : Float64, cy : Float64, rx : Float64, ry : Float64) : Nil
        kappa = 0.5522847498
        ox = rx * kappa
        oy = ry * kappa

        page.move_to(cx - rx, cy)
        page.curve_to(cx - rx, cy + oy, cx - ox, cy + ry, cx, cy + ry)
        page.curve_to(cx + ox, cy + ry, cx + rx, cy + oy, cx + rx, cy)
        page.curve_to(cx + rx, cy - oy, cx + ox, cy - ry, cx, cy - ry)
        page.curve_to(cx - ox, cy - ry, cx - rx, cy - oy, cx - rx, cy)
        page.close_path
      end

      private def draw_line(node : XML::Node, style : Style) : Nil
        # A line has no interior: without a stroke nothing is visible.
        return unless style.strokes?

        x1 = parse_coord(node["x1"]?) || 0.0
        y1 = parse_coord(node["y1"]?) || 0.0
        x2 = parse_coord(node["x2"]?) || 0.0
        y2 = parse_coord(node["y2"]?) || 0.0

        apply_style(style)
        page.move_to(x1, y1)
        page.line_to(x2, y2)
        page.stroke
      end

      private def draw_polyline(node : XML::Node, style : Style) : Nil
        points = parse_points(node["points"]?)
        return if points.size < 2

        apply_style(style)
        trace_points(points)
        paint(style)
      end

      private def draw_polygon(node : XML::Node, style : Style) : Nil
        points = parse_points(node["points"]?)
        return if points.size < 3

        apply_style(style)
        trace_points(points)
        page.close_path
        paint(style)
      end

      private def trace_points(points : Array(Tuple(Float64, Float64))) : Nil
        page.move_to(points[0][0], points[0][1])
        points[1..].each { |point| page.line_to(point[0], point[1]) }
      end

      private def draw_path(node : XML::Node, style : Style) : Nil
        d = node["d"]?
        return unless d

        commands = PathParser.parse(d)
        return if commands.empty?

        apply_style(style)
        commands.each do |cmd|
          case cmd.type
          when 'M'
            page.move_to(cmd.args[0], cmd.args[1])
          when 'L'
            page.line_to(cmd.args[0], cmd.args[1])
          when 'C'
            page.curve_to(cmd.args[0], cmd.args[1], cmd.args[2], cmd.args[3], cmd.args[4], cmd.args[5])
          when 'Z'
            page.close_path
          end
        end
        paint(style)
      end

      private def draw_text(node : XML::Node, style : Style) : Nil
        tx = parse_coord(node["x"]?) || 0.0
        ty = parse_coord(node["y"]?) || 0.0
        content = node.content.strip
        return if content.empty? || !style.fills?

        font_size = parse_coord(get_style(node, "font-size")) || 12.0

        apply_style(style)
        # Flip y back locally so glyphs are upright in the y-down space.
        page.transform(1.0, 0.0, 0.0, -1.0, tx, ty)
        page.font("Helvetica", size: font_size)
        page.text(content, at: {0.0, 0.0})
      end

      # Sets colors and line width from the style. Callers are inside a
      # q/Q pair, so nothing leaks.
      private def apply_style(style : Style) : Nil
        if style.fills? && (fill = style.fill) && (rgb = Color.parse(fill))
          page.fill_color(rgb[0], rgb[1], rgb[2])
        end
        if style.strokes? && (stroke = style.stroke) && (rgb = Color.parse(stroke))
          page.stroke_color(rgb[0], rgb[1], rgb[2])
        end
        if sw = style.stroke_width
          page.line_width(sw)
        end
      end

      private def paint(style : Style) : Nil
        if style.fills? && style.strokes?
          page.fill_stroke
        elsif style.fills?
          page.fill
        elsif style.strokes?
          page.stroke
        else
          page.end_path
        end
      end

      private def apply_transform(transform_str : String?) : Nil
        return unless transform_str
        matrix = Transform.parse(transform_str)
        return if matrix == Transform::IDENTITY
        page.transform(*matrix)
      end

      # Gets a style value from either the style attribute or a direct attribute.
      private def get_style(node : XML::Node, property : String) : String?
        if style = node["style"]?
          style.split(';').each do |declaration|
            parts = declaration.split(':', 2)
            if parts.size == 2 && parts[0].strip == property
              return parts[1].strip
            end
          end
        end

        node[property]?
      end

      private def parse_coord(value : String?) : Float64?
        Parser.parse_length(value)
      end

      private def parse_points(value : String?) : Array(Tuple(Float64, Float64))
        return [] of Tuple(Float64, Float64) unless value
        numbers = value.strip.split(/[\s,]+/).compact_map(&.to_f?)
        points = [] of Tuple(Float64, Float64)
        i = 0
        while i + 1 < numbers.size
          points << {numbers[i], numbers[i + 1]}
          i += 2
        end
        points
      end
    end
  end
end
