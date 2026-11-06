module PDF
  module SVG
    class Renderer
      # A resolved fill or stroke paint: a color with alpha, or a gradient.
      private record ColorPaint, rgb : Tuple(Float64, Float64, Float64), alpha : Float64
      private alias Paint = ColorPaint | Gradient

      # The painting operator for each {fill, stroke, even-odd} combination.
      private PAINT_OPERATORS = {
        {true, true, false}   => "B",
        {true, true, true}    => "B*",
        {true, false, false}  => "f",
        {true, false, true}   => "f*",
        {false, true, false}  => "S",
        {false, true, true}   => "S",
        {false, false, false} => "n",
        {false, false, true}  => "n",
      }

      private LINE_CAPS  = {"butt" => :butt, "round" => :round, "square" => :square}
      private LINE_JOINS = {"miter" => :miter, "miter-clip" => :miter, "arcs" => :miter, "round" => :round, "bevel" => :bevel}

      # Fills and strokes a shape outline with the element's style.
      # `closed_fill` is false for line, which has no interior.
      private def paint_shape(commands : Array(PathCommand), style : Style, *, closed_fill : Bool = true) : Nil
        return if style.hidden?

        fill = closed_fill ? fill_paint(style) : nil
        stroke = stroke_paint(style)
        if fill.is_a?(Gradient) || stroke.is_a?(Gradient)
          paint_fill_separately(commands, style, fill) if fill
          paint_stroke_separately(commands, style, stroke) if stroke
        else
          paint_colors(commands, style, fill.as(ColorPaint?), stroke.as(ColorPaint?))
        end
      end

      # The common case: one path, solid colors, one painting operator.
      private def paint_colors(commands : Array(PathCommand), style : Style, fill : ColorPaint?, stroke : ColorPaint?) : Nil
        return unless fill || stroke

        fill.try { |paint| page.fill_color(*paint.rgb) }
        stroke.try { |paint| page.stroke_color(*paint.rgb) }
        apply_opacity(fill.try(&.alpha), stroke.try(&.alpha), style)
        apply_stroke_properties(style) if stroke
        Geometry.emit(page, commands)
        emit_paint(!fill.nil?, !stroke.nil?, evenodd?(style))
      end

      private def paint_fill_separately(commands : Array(PathCommand), style : Style, paint : Paint) : Nil
        case paint
        when ColorPaint
          save
          paint_colors(commands, style, paint, nil)
          restore
        when Gradient
          fill_gradient(commands, style, paint)
        end
      end

      private def paint_stroke_separately(commands : Array(PathCommand), style : Style, paint : Paint) : Nil
        case paint
        when ColorPaint
          save
          paint_colors(commands, style, nil, paint)
          restore
        when Gradient
          stroke_gradient(commands, style, paint)
        end
      end

      # Clips to the outline and paints the shading over it.
      private def fill_gradient(commands : Array(PathCommand), style : Style, gradient : Gradient) : Nil
        box = Geometry.bbox(commands)
        return unless box
        matrix = gradient.matrix(box)
        coords = gradient.coords(viewport_reference_size)
        return unless matrix && coords

        save
        Geometry.emit(page, commands)
        evenodd?(style) ? page.clip_even_odd! : page.clip!
        apply_gradient_alpha(gradient, coords, matrix, box, fill: opacity_value(style, "fill-opacity"), stroke: nil)
        concat(matrix)
        page.shade(page.register_shading(gradient.color_shading(coords)))
        restore
      end

      # Strokes the outline with a shading pattern placed in page space.
      private def stroke_gradient(commands : Array(PathCommand), style : Style, gradient : Gradient) : Nil
        box = Geometry.bbox(commands)
        return unless box
        matrix = gradient.matrix(box)
        coords = gradient.coords(viewport_reference_size)
        return unless matrix && coords

        save
        margin = stroke_width(style) * {miter_limit(style), 2.0}.max
        mask_box = {box[0] - margin, box[1] - margin, box[2] + margin, box[3] + margin}
        apply_gradient_alpha(gradient, coords, matrix, mask_box, fill: nil, stroke: opacity_value(style, "stroke-opacity"))
        page.stroke_pattern(register_gradient_pattern(gradient, coords, matrix))
        apply_stroke_properties(style)
        Geometry.emit(page, commands)
        page.stroke
        restore
      end

      private def register_gradient_pattern(gradient : Gradient, coords : Array(Float64), matrix : Transform::Matrix) : String
        pattern = Objects::Dictionary.new
        pattern["Type"] = Objects::Name.new("Pattern")
        pattern["PatternType"] = Objects::Number.new(2)
        pattern["Shading"] = page.document.register_object(gradient.color_shading(coords)).reference
        pattern["Matrix"] = Objects::Array.new(Transform.multiply(@ctm, matrix).to_a)
        page.register_pattern(pattern)
      end

      # Sets the constant opacity, plus a luminosity soft mask built from
      # the stop opacities when the gradient is translucent. The mask
      # form lives in the current user space and covers `box`.
      private def apply_gradient_alpha(gradient : Gradient, coords : Array(Float64), matrix : Transform::Matrix, box : Geometry::Box, *, fill : Float64?, stroke : Float64?) : Nil
        gs = Objects::ExtGState.new
        gs.fill_opacity = fill if fill && fill < 1.0
        gs.stroke_opacity = stroke if stroke && stroke < 1.0
        gs.soft_mask = soft_mask(gradient, coords, matrix, box) if gradient.translucent?
        return unless gs.fill_opacity || gs.stroke_opacity || gs.soft_mask

        page.apply_graphics_state(gs)
      end

      private def soft_mask(gradient : Gradient, coords : Array(Float64), matrix : Transform::Matrix, box : Geometry::Box) : Objects::Dictionary
        document = page.document
        alpha_ref = document.register_object(gradient.alpha_shading(coords)).reference

        shadings = Objects::Dictionary.new
        shadings["A"] = alpha_ref
        resources = Objects::Dictionary.new
        resources["Shading"] = shadings

        group = Objects::Dictionary.new
        group["Type"] = Objects::Name.new("Group")
        group["S"] = Objects::Name.new("Transparency")
        group["CS"] = Objects::Name.new("DeviceGray")

        form = Objects::Stream.new
        form["Type"] = Objects::Name.new("XObject")
        form["Subtype"] = Objects::Name.new("Form")
        form["BBox"] = Objects::Array.new(box.to_a)
        form["Group"] = group
        form["Resources"] = resources
        form.data = "q #{matrix.join(' ') { |v| format_number(v) }} cm /A sh Q\n"

        mask = Objects::Dictionary.new
        mask["Type"] = Objects::Name.new("Mask")
        mask["S"] = Objects::Name.new("Luminosity")
        mask["G"] = document.register_object(form).reference
        mask
      end

      private def emit_paint(fill : Bool, stroke : Bool, evenodd : Bool) : Nil
        case PAINT_OPERATORS[{fill, stroke, evenodd}]
        when "B"  then page.fill_stroke
        when "B*" then page.fill_stroke_even_odd
        when "f"  then page.fill
        when "f*" then page.fill_even_odd
        when "S"  then page.stroke
        else           page.end_path
        end
      end

      # -- Paint resolution --------------------------------------------------

      # Fill defaults to black. A color's alpha includes fill-opacity;
      # the group opacity is applied when painting.
      private def fill_paint(style : Style) : Paint?
        resolve_paint(style["fill"] || "black", style, own_opacity(style, "fill-opacity"))
      end

      # Stroke defaults to none; a zero width paints nothing.
      private def stroke_paint(style : Style) : Paint?
        return unless value = style["stroke"]
        return if stroke_width(style) <= 0
        resolve_paint(value, style, own_opacity(style, "stroke-opacity"))
      end

      # Resolves a paint value: none, a color, currentColor, or
      # url(#gradient) with an optional fallback color.
      private def resolve_paint(value : String, style : Style, opacity : Float64) : Paint?
        value = value.strip
        return if value == "none"

        if value.starts_with?("url(")
          return gradient_paint(value, style, opacity)
        end

        value = style["color"] || "black" if value == "currentColor"
        rgba = Color.parse_rgba(value)
        rgba ? ColorPaint.new({rgba[0], rgba[1], rgba[2]}, rgba[3] * opacity) : nil
      end

      private def gradient_paint(value : String, style : Style, opacity : Float64) : Paint?
        target = url_target(value)
        if target && {"linearGradient", "radialGradient"}.includes?(target.name)
          gradient = build_gradient(target)
          return if gradient.stops.empty? # no stops paints nothing
          return gradient_as_color(gradient, opacity) || gradient
        end

        fallback = value.sub(/\Aurl\([^)]*\)/, "").strip
        fallback.empty? ? nil : resolve_paint(fallback, style, opacity)
      end

      # A gradient with fewer than two stops, or with coincident end
      # points, paints as a single color.
      private def gradient_as_color(gradient : Gradient, opacity : Float64) : Paint?
        stops = gradient.stops
        return unless stops.size == 1 || gradient.coords(viewport_reference_size).nil?

        ColorPaint.new(stops.last.rgb, stops.last.opacity * opacity)
      end

      private def build_gradient(node : XML::Node) : Gradient
        if (spread = node["spreadMethod"]?) && spread != "pad"
          warn("Unsupported spreadMethod #{spread}; drawn as pad")
        end
        lookup = ->(id : String) { @ids[id]? }
        stop_style = ->(stop : XML::Node) do
          values = declared(stop)
          color = values["stop-color"]?
          color = values["color"]? || declared(node)["color"]? || "black" if color == "currentColor"
          {color, values["stop-opacity"]?}
        end
        Gradient.from_node(node, lookup, stop_style)
      end

      # -- State helpers -----------------------------------------------------

      # Emits fill and stroke opacity (paint alpha times the element and
      # group opacity) when either is below 1.
      private def apply_opacity(fill_alpha : Float64?, stroke_alpha : Float64?, style : Style) : Nil
        fill = fill_alpha.try(&.*(style.opacity))
        stroke = stroke_alpha.try(&.*(style.opacity))
        return unless (fill && fill < 1.0) || (stroke && stroke < 1.0)

        page.set_opacity(fill: fill, stroke: stroke)
      end

      # The fill-opacity or stroke-opacity value of the style.
      private def own_opacity(style : Style, property : String) : Float64
        style[property].try { |value| Style.parse_fraction(value) } || 1.0
      end

      # The fill-opacity or stroke-opacity value times the group opacity.
      private def opacity_value(style : Style, property : String) : Float64
        own_opacity(style, property) * style.opacity
      end

      private def apply_stroke_properties(style : Style) : Nil
        if value = style["stroke-width"]
          page.line_width(length(value, :other, style.font_size))
        end
        style["stroke-linecap"].try { |name| LINE_CAPS[name]?.try { |cap| page.line_cap(cap) } }
        style["stroke-linejoin"].try { |name| LINE_JOINS[name]?.try { |join| page.line_join(join) } }
        if (value = style["stroke-miterlimit"]) && (limit = value.to_f?) && limit >= 1
          page.miter_limit(limit)
        end
        apply_dash(style)
      end

      # stroke-dasharray: an odd list repeats once; negative values make
      # the whole value invalid; all zeros means solid.
      private def apply_dash(style : Style) : Nil
        value = style["stroke-dasharray"]
        return unless value && value != "none"

        dashes = value.split(/[\s,]+/).reject(&.empty?).map { |part| length(part, :other) }
        return if dashes.empty? || dashes.any?(&.negative?) || dashes.sum <= 0

        dashes += dashes if dashes.size.odd?
        offset = length(style["stroke-dashoffset"], :other)
        page.dash(dashes, phase: offset)
      end

      private def stroke_width(style : Style) : Float64
        value = style["stroke-width"]
        value ? length(value, :other, style.font_size) : 1.0
      end

      private def miter_limit(style : Style) : Float64
        style["stroke-miterlimit"].try(&.to_f?) || 4.0
      end

      private def evenodd?(style : Style) : Bool
        style["fill-rule"] == "evenodd"
      end

      private def viewport_reference_size : Tuple(Float64, Float64)
        @viewports.last? || @root_viewport
      end

      private def format_number(value : Float64) : String
        value == value.round ? value.to_i64.to_s : "%.6f".%(value).rstrip('0').rstrip('.')
      end
    end
  end
end
