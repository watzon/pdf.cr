module PDF
  module SVG
    # Shape outlines in SVG user space, as absolute M, L, C and Z commands.
    # A plain rectangle is one 'R' command (x, y, width, height) so that it
    # is emitted with the compact `re` operator.
    #
    # The renderer converts every shape to a list of `PathCommand`s first.
    # This gives one place to compute bounding boxes (for
    # objectBoundingBox gradients and clip paths), to transform outlines
    # (clipPath children with their own transform), and to emit them.
    module Geometry
      alias Point = Tuple(Float64, Float64)

      # Axis-aligned box: {min_x, min_y, max_x, max_y}.
      alias Box = Tuple(Float64, Float64, Float64, Float64)

      # Bezier control-point offset for a quarter ellipse.
      KAPPA = 0.5522847498

      # Returns a closed ellipse outline (four cubic curves).
      def self.ellipse(cx : Float64, cy : Float64, rx : Float64, ry : Float64) : Array(PathCommand)
        ox = rx * KAPPA
        oy = ry * KAPPA
        [
          PathCommand.new('M', [cx - rx, cy]),
          PathCommand.new('C', [cx - rx, cy + oy, cx - ox, cy + ry, cx, cy + ry]),
          PathCommand.new('C', [cx + ox, cy + ry, cx + rx, cy + oy, cx + rx, cy]),
          PathCommand.new('C', [cx + rx, cy - oy, cx + ox, cy - ry, cx, cy - ry]),
          PathCommand.new('C', [cx - ox, cy - ry, cx - rx, cy - oy, cx - rx, cy]),
          PathCommand.new('Z'),
        ]
      end

      # Returns a rectangle outline. With rx and ry above zero the corners
      # are elliptical quarter arcs (SVG rounded rect).
      def self.rect(x : Float64, y : Float64, w : Float64, h : Float64, rx : Float64 = 0.0, ry : Float64 = 0.0) : Array(PathCommand)
        return [PathCommand.new('R', [x, y, w, h])] if rx <= 0 || ry <= 0

        ox = rx * KAPPA
        oy = ry * KAPPA
        r = x + w
        b = y + h
        [
          PathCommand.new('M', [x + rx, y]),
          PathCommand.new('L', [r - rx, y]),
          PathCommand.new('C', [r - rx + ox, y, r, y + ry - oy, r, y + ry]),
          PathCommand.new('L', [r, b - ry]),
          PathCommand.new('C', [r, b - ry + oy, r - rx + ox, b, r - rx, b]),
          PathCommand.new('L', [x + rx, b]),
          PathCommand.new('C', [x + rx - ox, b, x, b - ry + oy, x, b - ry]),
          PathCommand.new('L', [x, y + ry]),
          PathCommand.new('C', [x, y + ry - oy, x + rx - ox, y, x + rx, y]),
          PathCommand.new('Z'),
        ]
      end

      # Returns an open polyline through the points.
      def self.polyline(points : Array(Point)) : Array(PathCommand)
        commands = [PathCommand.new('M', [points[0][0], points[0][1]])]
        points[1..].each { |point| commands << PathCommand.new('L', [point[0], point[1]]) }
        commands
      end

      # Returns a closed polygon through the points.
      def self.polygon(points : Array(Point)) : Array(PathCommand)
        polyline(points) << PathCommand.new('Z')
      end

      # Maps every point of the outline through an affine matrix.
      def self.transform(commands : Array(PathCommand), matrix : Transform::Matrix) : Array(PathCommand)
        return commands if matrix == Transform::IDENTITY

        expand_rects(commands).map do |cmd|
          args = [] of Float64
          cmd.args.each_slice(2) do |pair|
            x, y = Transform.apply(matrix, pair[0], pair[1])
            args << x << y
          end
          PathCommand.new(cmd.type, args)
        end
      end

      # Replaces 'R' commands with the equivalent closed polygon.
      def self.expand_rects(commands : Array(PathCommand)) : Array(PathCommand)
        return commands unless commands.any? { |cmd| cmd.type == 'R' }

        commands.flat_map do |cmd|
          next [cmd] unless cmd.type == 'R'
          x, y, w, h = cmd.args
          polygon([{x, y}, {x + w, y}, {x + w, y + h}, {x, y + h}])
        end
      end

      # Returns the exact bounding box of the outline (curve extrema
      # included), or nil when the outline has no points.
      def self.bbox(commands : Array(PathCommand)) : Box?
        xs = [] of Float64
        ys = [] of Float64
        current = {0.0, 0.0}
        expand_rects(commands).each do |cmd|
          case cmd.type
          when 'M', 'L'
            current = {cmd.args[0], cmd.args[1]}
            xs << current[0]
            ys << current[1]
          when 'C'
            a = cmd.args
            add_curve_extent(xs, current[0], a[0], a[2], a[4])
            add_curve_extent(ys, current[1], a[1], a[3], a[5])
            current = {a[4], a[5]}
          end
        end
        return if xs.empty?

        {xs.min, ys.min, xs.max, ys.max}
      end

      # Adds the end point and the interior extrema of one cubic Bezier
      # coordinate to the list.
      private def self.add_curve_extent(values : Array(Float64), p0 : Float64, p1 : Float64, p2 : Float64, p3 : Float64) : Nil
        values << p0 << p3
        # Derivative coefficients: a t^2 + b t + c
        a = 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3)
        b = 6.0 * (p0 - 2.0 * p1 + p2)
        c = 3.0 * (p1 - p0)
        derivative_roots(a, b, c).each do |root|
          next unless 0.0 < root < 1.0
          rest = 1.0 - root
          values << rest ** 3 * p0 + 3.0 * rest * rest * root * p1 + 3.0 * rest * root * root * p2 + root ** 3 * p3
        end
      end

      private def self.derivative_roots(a : Float64, b : Float64, c : Float64) : Array(Float64)
        if a.abs < 1e-12
          return b.abs < 1e-12 ? [] of Float64 : [-c / b]
        end

        disc = b * b - 4.0 * a * c
        return [] of Float64 if disc < 0

        root = Math.sqrt(disc)
        [(-b + root) / (2.0 * a), (-b - root) / (2.0 * a)]
      end

      # Emits the outline as path construction operators.
      def self.emit(page : Page, commands : Array(PathCommand)) : Nil
        commands.each do |cmd|
          a = cmd.args
          case cmd.type
          when 'M' then page.move_to(a[0], a[1])
          when 'L' then page.line_to(a[0], a[1])
          when 'C' then page.curve_to(a[0], a[1], a[2], a[3], a[4], a[5])
          when 'R' then page.rectangle(a[0], a[1], a[2], a[3])
          when 'Z' then page.close_path
          end
        end
      end
    end
  end
end
