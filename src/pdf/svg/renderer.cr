require "xml"

module PDF
  module SVG
    # Renders an SVG document onto a PDF page.
    #
    # Traverses the SVG element tree and translates each element into
    # corresponding PDF drawing operations. Handles coordinate system
    # transformation (SVG y-axis is top-down, PDF is bottom-up).
    #
    # Ported from Prawn::SVG::Renderer.
    class Renderer
      # The PDF page to draw on
      getter page : Page

      # The parsed SVG document
      getter parser : Parser

      # Position to draw the SVG at [x, y] in PDF coordinates
      getter x : Float64
      getter y : Float64

      # Output dimensions
      getter output_width : Float64
      getter output_height : Float64

      # Scale factors
      getter x_scale : Float64
      getter y_scale : Float64

      # Warnings generated during rendering
      getter warnings : Array(String) = [] of String

      def initialize(
        @page : Page,
        @parser : Parser,
        *,
        x : Float64 = 0.0,
        y : Float64 = 0.0,
        width : Float64? = nil,
        height : Float64? = nil
      )
        @x = x
        @y = y

        # Calculate output dimensions
        svg_w = parser.width
        svg_h = parser.height

        if vb = parser.viewbox
          svg_w = vb[2] if vb[2] > 0
          svg_h = vb[3] if vb[3] > 0
        end

        @output_width = width || svg_w
        @output_height = height || svg_h

        @x_scale = @output_width / svg_w
        @y_scale = @output_height / svg_h
      end

      # Draws the SVG onto the PDF page.
      def draw : Nil
        # Save graphics state
        page.save_graphics_state

        # Set up coordinate transformation:
        # SVG origin is top-left, y increases downward
        # PDF origin is bottom-left, y increases upward
        # We translate to the target position and flip y
        parser.elements.each do |element|
          render_element(element)
        end

        page.restore_graphics_state
      end

      private def render_element(node : XML::Node) : Nil
        return unless node.element?

        tag = node.name.downcase

        # Parse style attributes
        fill_color = get_style(node, "fill")
        stroke_color_val = get_style(node, "stroke")
        stroke_width_val = get_style(node, "stroke-width")
        opacity_val = get_style(node, "opacity")
        transform_val = node["transform"]?

        case tag
        when "g"
          page.save_graphics_state
          apply_transform(transform_val)
          apply_styles(node)
          node.children.each { |child| render_element(child) }
          page.restore_graphics_state

        when "rect"
          draw_rect(node)

        when "circle"
          draw_circle(node)

        when "ellipse"
          draw_ellipse(node)

        when "line"
          draw_line(node)

        when "polyline"
          draw_polyline(node)

        when "polygon"
          draw_polygon(node)

        when "path"
          draw_path(node)

        when "text"
          draw_text(node)

        when "svg"
          # Nested SVG - process children
          page.save_graphics_state
          node.children.each { |child| render_element(child) }
          page.restore_graphics_state

        when "defs", "title", "desc", "metadata", "style"
          # Skip non-renderable elements

        else
          # Try to render children for unknown container elements
          node.children.each { |child| render_element(child) }
        end
      end

      private def draw_rect(node : XML::Node) : Nil
        rx = parse_coord(node["x"]?) || 0.0
        ry_svg = parse_coord(node["y"]?) || 0.0
        w = parse_coord(node["width"]?) || 0.0
        h = parse_coord(node["height"]?) || 0.0
        return if w <= 0 || h <= 0

        # Convert SVG coordinates to PDF coordinates
        px, py = svg_to_pdf(rx, ry_svg)

        page.save_graphics_state
        apply_styles(node)
        page.rectangle(px, py, w * @x_scale, h * @y_scale)
        apply_fill_and_stroke(node)
        page.restore_graphics_state
      end

      private def draw_circle(node : XML::Node) : Nil
        cx = parse_coord(node["cx"]?) || 0.0
        cy = parse_coord(node["cy"]?) || 0.0
        r = parse_coord(node["r"]?) || 0.0
        return if r <= 0

        px, py = svg_to_pdf(cx, cy)
        sr = r * @x_scale

        page.save_graphics_state
        apply_styles(node)
        # Approximate circle with 4 cubic Bezier curves
        kappa = 0.5522847498 # 4 * (sqrt(2) - 1) / 3
        draw_ellipse_path(px, py, sr, sr * @y_scale / @x_scale)
        apply_fill_and_stroke(node)
        page.restore_graphics_state
      end

      private def draw_ellipse(node : XML::Node) : Nil
        cx = parse_coord(node["cx"]?) || 0.0
        cy = parse_coord(node["cy"]?) || 0.0
        rx = parse_coord(node["rx"]?) || 0.0
        ry = parse_coord(node["ry"]?) || 0.0
        return if rx <= 0 || ry <= 0

        px, py = svg_to_pdf(cx, cy)

        page.save_graphics_state
        apply_styles(node)
        draw_ellipse_path(px, py, rx * @x_scale, ry * @y_scale)
        apply_fill_and_stroke(node)
        page.restore_graphics_state
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
      end

      private def draw_line(node : XML::Node) : Nil
        x1 = parse_coord(node["x1"]?) || 0.0
        y1 = parse_coord(node["y1"]?) || 0.0
        x2 = parse_coord(node["x2"]?) || 0.0
        y2 = parse_coord(node["y2"]?) || 0.0

        px1, py1 = svg_to_pdf(x1, y1)
        px2, py2 = svg_to_pdf(x2, y2)

        page.save_graphics_state
        apply_styles(node)
        page.move_to(px1, py1)
        page.line_to(px2, py2)
        page.stroke
        page.restore_graphics_state
      end

      private def draw_polyline(node : XML::Node) : Nil
        points = parse_points(node["points"]?)
        return if points.size < 2

        page.save_graphics_state
        apply_styles(node)

        first = points[0]
        px, py = svg_to_pdf(first[0], first[1])
        page.move_to(px, py)

        points[1..].each do |pt|
          px, py = svg_to_pdf(pt[0], pt[1])
          page.line_to(px, py)
        end

        apply_fill_and_stroke(node)
        page.restore_graphics_state
      end

      private def draw_polygon(node : XML::Node) : Nil
        points = parse_points(node["points"]?)
        return if points.size < 3

        page.save_graphics_state
        apply_styles(node)

        first = points[0]
        px, py = svg_to_pdf(first[0], first[1])
        page.move_to(px, py)

        points[1..].each do |pt|
          px, py = svg_to_pdf(pt[0], pt[1])
          page.line_to(px, py)
        end

        # Close the path
        px, py = svg_to_pdf(first[0], first[1])
        page.line_to(px, py)

        apply_fill_and_stroke(node)
        page.restore_graphics_state
      end

      private def draw_path(node : XML::Node) : Nil
        d = node["d"]?
        return unless d

        commands = PathParser.parse(d)
        return if commands.empty?

        page.save_graphics_state
        apply_styles(node)

        commands.each do |cmd|
          case cmd.type
          when 'M'
            px, py = svg_to_pdf(cmd.args[0], cmd.args[1])
            page.move_to(px, py)
          when 'L'
            px, py = svg_to_pdf(cmd.args[0], cmd.args[1])
            page.line_to(px, py)
          when 'C'
            px1, py1 = svg_to_pdf(cmd.args[0], cmd.args[1])
            px2, py2 = svg_to_pdf(cmd.args[2], cmd.args[3])
            px3, py3 = svg_to_pdf(cmd.args[4], cmd.args[5])
            page.curve_to(px1, py1, px2, py2, px3, py3)
          when 'Z'
            page.close_stroke
          end
        end

        apply_fill_and_stroke(node)
        page.restore_graphics_state
      end

      private def draw_text(node : XML::Node) : Nil
        tx = parse_coord(node["x"]?) || 0.0
        ty = parse_coord(node["y"]?) || 0.0
        content = node.content.strip
        return if content.empty?

        px, py = svg_to_pdf(tx, ty)

        font_size = parse_coord(get_style(node, "font-size")) || 12.0
        font_size *= @y_scale

        page.save_graphics_state
        apply_styles(node)
        page.font("Helvetica", size: font_size)
        page.text(content, at: {px, py})
        page.restore_graphics_state
      end

      # Converts SVG coordinates to PDF coordinates.
      # SVG: origin top-left, y increases downward
      # PDF: origin bottom-left, y increases upward
      private def svg_to_pdf(svg_x : Float64, svg_y : Float64) : Tuple(Float64, Float64)
        pdf_x = @x + svg_x * @x_scale
        pdf_y = @y - svg_y * @y_scale
        {pdf_x, pdf_y}
      end

      private def apply_styles(node : XML::Node) : Nil
        # Fill color
        fill = get_style(node, "fill")
        if fill && fill != "none"
          if rgb = Color.parse(fill)
            page.fill_color(rgb[0], rgb[1], rgb[2])
          end
        end

        # Stroke color
        stroke_val = get_style(node, "stroke")
        if stroke_val && stroke_val != "none"
          if rgb = Color.parse(stroke_val)
            page.stroke_color(rgb[0], rgb[1], rgb[2])
          end
        end

        # Stroke width
        sw = get_style(node, "stroke-width")
        if sw
          if w = parse_coord(sw)
            page.line_width(w * @x_scale)
          end
        end
      end

      private def apply_fill_and_stroke(node : XML::Node) : Nil
        fill = get_style(node, "fill")
        stroke_val = get_style(node, "stroke")

        has_fill = fill.nil? || (fill != "none") # default fill is black
        has_stroke = stroke_val && stroke_val != "none"

        if has_fill && has_stroke
          page.fill_stroke
        elsif has_fill
          page.fill
        elsif has_stroke
          page.stroke
        else
          page.end_path
        end
      end

      private def apply_transform(transform_str : String?) : Nil
        return unless transform_str
        matrix = Transform.parse(transform_str)
        return if matrix == Transform::IDENTITY
        # Apply transformation matrix to PDF
        # PDF transformation matrix: [a b c d e f]
        a, b, c, d, e, f = matrix
        # Adjust for SVG-to-PDF coordinate flip
        page.transform(a, -b, -c, d, e * @x_scale + @x, -f * @y_scale + @y)
      end

      # Gets a style value from either the style attribute or a direct attribute.
      private def get_style(node : XML::Node, property : String) : String?
        # Check inline style first
        style = node["style"]?
        if style
          style.split(';').each do |declaration|
            parts = declaration.split(':')
            if parts.size == 2 && parts[0].strip == property
              return parts[1].strip
            end
          end
        end

        # Fall back to direct attribute
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
