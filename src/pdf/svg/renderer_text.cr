module PDF
  module SVG
    class Renderer
      # One piece of text drawn with one style at one position.
      private record TextRun,
        text : String,
        style : Style,
        font : String,
        size : Float64,
        x : Float64,
        y : Float64,
        width : Float64,
        chunk : Int32

      # The x, y, dx and dy lists of one text or tspan element. Each list
      # entry applies to one character of the element, in order.
      private class PositionFrame
        getter x : Array(Float64)
        getter y : Array(Float64)
        getter dx : Array(Float64)
        getter dy : Array(Float64)
        property index = 0

        def initialize(@x, @y, @dx, @dy)
        end
      end

      # Builds text runs: collapses white space, applies per-character
      # positions and splits the text into anchored chunks.
      private class TextLayout
        getter runs = [] of TextRun
        property x = 0.0
        property y = 0.0
        @chunk = 0
        @pending_space : Tuple(Style, Int32)? = nil
        @started = false
        @buffer = String::Builder.new
        @run_x = 0.0
        @run_y = 0.0
        @run_width = 0.0
        @run_style : Style?
        @run_font = ""
        @run_size = 0.0

        # Normalizes one character. Returns nil when the character is
        # white space. The first space of a run of white space is kept,
        # with its style and position-frame depth, and emitted before the
        # next visible character; leading and trailing white space is
        # dropped.
        def visible_char(char : Char, style : Style, depth : Int32) : Char?
          if char.whitespace?
            @pending_space ||= {style, depth} if @started
            return
          end
          char
        end

        # Returns the style and frame depth of the kept space, if any.
        def take_pending_space : Tuple(Style, Int32)?
          pending = @pending_space
          @pending_space = nil
          pending
        end

        def new_chunk : Nil
          flush
          @chunk += 1 if @started || !@runs.empty?
        end

        # Appends a character with its advance width to the current run,
        # starting a new run when the style changes.
        def add(char : Char, style : Style, font : String, size : Float64, advance : Float64) : Nil
          flush if @run_style && !@run_style.same?(style)
          if @buffer.empty?
            @run_x = @x
            @run_y = @y
            @run_style = style
            @run_font = font
            @run_size = size
          end
          @started = true
          @buffer << char
          @run_width += advance
          @x += advance
        end

        def flush : Nil
          style = @run_style
          if style && !@buffer.empty?
            @runs << TextRun.new(@buffer.to_s, style, @run_font, @run_size, @run_x, @run_y, @run_width, @chunk)
          end
          @buffer = String::Builder.new
          @run_width = 0.0
          @run_style = nil
        end
      end

      private def draw_text(node : XML::Node, style : Style) : Nil
        layout = TextLayout.new
        frames = [] of PositionFrame
        collect_text(node, style, layout, frames)
        layout.flush
        runs = anchor_runs(layout.runs)
        return if runs.empty?

        bbox = text_bbox(runs)
        runs.each { |run| draw_text_run(run, bbox) }
      end

      # Walks text nodes and tspan elements in document order.
      private def collect_text(node : XML::Node, style : Style, layout : TextLayout, frames : Array(PositionFrame)) : Nil
        frames << position_frame(node)
        node.children.each do |child|
          if child.text? || child.cdata?
            child.content.each_char { |char| layout_char(char, style, layout, frames) }
          elsif child.element? && {"tspan", "a"}.includes?(child.name)
            child_style = style.derive(declared(child))
            next if child_style.display_none?
            layout.flush
            collect_text(child, child_style, layout, frames)
            layout.flush
          end
        end
        frames.pop
      end

      private def position_frame(node : XML::Node) : PositionFrame
        PositionFrame.new(
          length_list(node["x"]?, :x),
          length_list(node["y"]?, :y),
          length_list(node["dx"]?, :x),
          length_list(node["dy"]?, :y),
        )
      end

      private def length_list(value : String?, axis : Symbol) : Array(Float64)
        return [] of Float64 unless value
        value.split(/[\s,]+/).reject(&.empty?).map { |part| length(part, axis) }
      end

      private def layout_char(char : Char, style : Style, layout : TextLayout, frames : Array(PositionFrame)) : Nil
        visible = layout.visible_char(char, style, frames.size)
        return unless visible

        if pending = layout.take_pending_space
          space_style, depth = pending
          layout_positioned(' ', space_style, layout, frames[0, depth])
        end
        layout_positioned(visible, style, layout, frames)
      end

      # Applies the innermost x, y, dx and dy entries for this character,
      # then adds it to the layout.
      private def layout_positioned(char : Char, style : Style, layout : TextLayout, frames : Array(PositionFrame)) : Nil
        abs_x = frame_value(frames, &.x)
        abs_y = frame_value(frames, &.y)
        dx = frame_value(frames, &.dx)
        dy = frame_value(frames, &.dy)
        frames.each { |frame| frame.index += 1 }

        if abs_x || abs_y
          # A space right before an absolutely positioned character is
          # not part of either chunk.
          return if char == ' '
          layout.new_chunk
          abs_x.try { |value| layout.x = value }
          abs_y.try { |value| layout.y = value }
        end
        if dx || dy
          layout.flush
          layout.x += dx || 0.0
          layout.y += dy || 0.0
        end

        font = text_font(style)
        size = style.font_size
        advance = page.document.font(font).glyph_width(char) * size / 1000.0
        layout.add(char, style, font, size, advance)
      end

      # Returns the entry for the current character from the innermost
      # frame whose list is long enough.
      private def frame_value(frames : Array(PositionFrame), & : PositionFrame -> Array(Float64)) : Float64?
        frames.reverse_each do |frame|
          list = yield frame
          if value = list[frame.index]?
            return value
          end
        end
        nil
      end

      private def text_font(style : Style) : String
        FontMap.resolve(style["font-family"], style["font-weight"], style["font-style"])
      end

      # Shifts each chunk by its text-anchor (start, middle or end), using
      # the anchor of the first run in the chunk.
      private def anchor_runs(runs : Array(TextRun)) : Array(TextRun)
        runs.group_by(&.chunk).values.flat_map do |chunk|
          factor = case chunk.first.style["text-anchor"]
                   when "middle" then 0.5
                   when "end"    then 1.0
                   else               0.0
                   end
          next chunk if factor == 0.0

          last = chunk.max_by { |run| run.x + run.width }
          shift = (last.x + last.width - chunk.first.x) * factor
          chunk.map { |run| run.copy_with(x: run.x - shift) }
        end
      end

      # Approximate box of the laid out text (ascent 0.8 em, descent 0.2 em).
      private def text_bbox(runs : Array(TextRun)) : Geometry::Box
        {
          runs.min_of(&.x),
          runs.min_of { |run| run.y - run.size * 0.8 },
          runs.max_of { |run| run.x + run.width },
          runs.max_of { |run| run.y + run.size * 0.2 },
        }
      end

      private def draw_text_run(run : TextRun, bbox : Geometry::Box) : Nil
        style = run.style
        return if style.hidden?
        paint = fill_paint(style)
        return unless paint

        save
        case paint
        when ColorPaint
          page.fill_color(*paint.rgb)
          apply_opacity(paint.alpha, nil, style)
        when Gradient
          return restore unless text_gradient(paint, style, bbox)
        end
        # Flip y back locally so glyphs are upright in the y-down space.
        concat({1.0, 0.0, 0.0, -1.0, run.x, run.y})
        page.font(run.font, size: run.size)
        page.text(run.text, at: {0.0, 0.0})
        restore
      end

      # Sets a gradient pattern as the text fill. Returns false when the
      # gradient cannot paint the text box.
      private def text_gradient(gradient : Gradient, style : Style, bbox : Geometry::Box) : Bool
        matrix = gradient.matrix(bbox)
        coords = gradient.coords(viewport_reference_size)
        return false unless matrix && coords

        apply_gradient_alpha(gradient, coords, matrix, bbox, fill: opacity_value(style, "fill-opacity"), stroke: nil)
        page.fill_pattern(register_gradient_pattern(gradient, coords, matrix))
        true
      end
    end
  end
end
