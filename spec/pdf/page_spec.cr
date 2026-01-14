require "../spec_helper"

describe PDF::Page do
  describe "initialization" do
    it "creates page with default size" do
      doc = PDF::Document.new
      page = PDF::Page.new(doc)
      page.width.should eq(612.0)
      page.height.should eq(792.0)
    end

    it "creates page with custom size" do
      doc = PDF::Document.new
      page = PDF::Page.new(doc, 400.0, 600.0)
      page.width.should eq(400.0)
      page.height.should eq(600.0)
    end
  end

  describe "#font" do
    it "sets current font" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.font("Helvetica", size: 14)
        result.should be(page) # Returns self for chaining
      end
    end
  end

  describe "#text" do
    it "raises if no font is set" do
      doc = PDF::Document.new
      doc.page do |page|
        expect_raises(Exception, /No font set/) do
          page.text("Hello", at: {72, 720})
        end
      end
    end

    it "returns self for chaining" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        result = page.text("Hello", at: {72, 720})
        result.should be(page)
      end
    end
  end

  describe "graphics operations" do
    it "supports stroke_color" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.stroke_color(1.0, 0.0, 0.0)
        result.should be(page)
      end
    end

    it "supports fill_color" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.fill_color(0.0, 0.0, 1.0)
        result.should be(page)
      end
    end

    it "supports line_width" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.line_width(2)
        result.should be(page)
      end
    end

    it "supports move_to and line_to" do
      doc = PDF::Document.new
      doc.page do |page|
        page.move_to(0, 0).line_to(100, 100).stroke
      end
    end

    it "supports rectangle" do
      doc = PDF::Document.new
      doc.page do |page|
        page.rectangle(10, 10, 50, 50).fill
      end
    end

    it "supports save_graphics_state with block" do
      doc = PDF::Document.new
      doc.page do |page|
        block_executed = false
        page.save_graphics_state do
          block_executed = true
        end
        block_executed.should be_true
      end
    end
  end

  describe "path operations" do
    it "supports curve_to (cubic bezier)" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.move_to(100, 100)
          .curve_to(150, 200, 250, 200, 300, 100)
          .stroke
        result.should be(page)
      end
    end

    it "supports curve_v (bezier with current point as first control)" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.move_to(100, 100)
          .curve_v(200, 150, 200, 100)
          .stroke
        result.should be(page)
      end
    end

    it "supports curve_y (bezier with endpoint as second control)" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.move_to(100, 100)
          .curve_y(150, 150, 200, 100)
          .stroke
        result.should be(page)
      end
    end

    it "supports close_path" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.move_to(100, 100)
          .line_to(200, 100)
          .line_to(150, 200)
          .close_path
          .stroke
        result.should be(page)
      end
    end

    it "supports close_stroke" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.move_to(100, 100)
          .line_to(200, 100)
          .line_to(150, 200)
          .close_stroke
        result.should be(page)
      end
    end

    it "supports fill_even_odd" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rectangle(10, 10, 50, 50).fill_even_odd
        result.should be(page)
      end
    end

    it "supports fill_stroke_even_odd" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rectangle(10, 10, 50, 50).fill_stroke_even_odd
        result.should be(page)
      end
    end

    it "supports close_fill_stroke" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.move_to(100, 100)
          .line_to(200, 100)
          .line_to(150, 200)
          .close_fill_stroke
        result.should be(page)
      end
    end

    it "supports close_fill_stroke_even_odd" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.move_to(100, 100)
          .line_to(200, 100)
          .line_to(150, 200)
          .close_fill_stroke_even_odd
        result.should be(page)
      end
    end

    it "supports end_path" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rectangle(10, 10, 50, 50).end_path
        result.should be(page)
      end
    end
  end

  describe "clipping operations" do
    it "supports clip" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rectangle(10, 10, 50, 50).clip.end_path
        result.should be(page)
      end
    end

    it "supports clip_even_odd" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rectangle(10, 10, 50, 50).clip_even_odd.end_path
        result.should be(page)
      end
    end

    it "supports clip! convenience method" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rectangle(10, 10, 50, 50).clip!
        result.should be(page)
      end
    end

    it "supports clip_even_odd! convenience method" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rectangle(10, 10, 50, 50).clip_even_odd!
        result.should be(page)
      end
    end
  end

  describe "graphics state parameters" do
    it "supports line_cap with enum" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.line_cap(PDF::Content::GraphicsState::LineCap::Round)
        result.should be(page)
      end
    end

    it "supports line_cap with symbol" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.line_cap(:round)
        result.should be(page)
        result = page.line_cap(:butt)
        result = page.line_cap(:square)
      end
    end

    it "raises for unknown line_cap" do
      doc = PDF::Document.new
      doc.page do |page|
        expect_raises(ArgumentError, /Unknown line cap/) do
          page.line_cap(:unknown)
        end
      end
    end

    it "supports line_join with enum" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.line_join(PDF::Content::GraphicsState::LineJoin::Round)
        result.should be(page)
      end
    end

    it "supports line_join with symbol" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.line_join(:round)
        result.should be(page)
        result = page.line_join(:miter)
        result = page.line_join(:bevel)
      end
    end

    it "raises for unknown line_join" do
      doc = PDF::Document.new
      doc.page do |page|
        expect_raises(ArgumentError, /Unknown line join/) do
          page.line_join(:unknown)
        end
      end
    end

    it "supports miter_limit" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.miter_limit(5.0)
        result.should be(page)
      end
    end

    it "supports dash pattern with array" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.dash([5, 3])
        result.should be(page)
      end
    end

    it "supports dash pattern with phase" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.dash([5, 3], phase: 2)
        result.should be(page)
      end
    end

    it "supports dash pattern struct" do
      doc = PDF::Document.new
      doc.page do |page|
        pattern = PDF::Content::GraphicsState::DashPattern.new([5.0, 3.0], 2.0)
        result = page.dash(pattern)
        result.should be(page)
      end
    end

    it "supports solid (reset dash)" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.solid
        result.should be(page)
      end
    end

    it "supports rendering_intent with enum" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rendering_intent(PDF::Content::GraphicsState::RenderingIntent::Perceptual)
        result.should be(page)
      end
    end

    it "supports rendering_intent with symbol" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rendering_intent(:perceptual)
        result.should be(page)
      end
    end

    it "raises for unknown rendering_intent" do
      doc = PDF::Document.new
      doc.page do |page|
        expect_raises(ArgumentError, /Unknown rendering intent/) do
          page.rendering_intent(:unknown)
        end
      end
    end

    it "supports flatness" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.flatness(1)
        result.should be(page)
      end
    end
  end

  describe "color operations" do
    it "supports stroke_color with named color" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.stroke_color(:red)
        result.should be(page)
      end
    end

    it "supports fill_color with named color" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.fill_color(:blue)
        result.should be(page)
      end
    end

    it "supports stroke_color with hex string" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.stroke_color("#FF0000")
        result.should be(page)
      end
    end

    it "supports fill_color with hex string" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.fill_color("#0000FF")
        result.should be(page)
      end
    end

    it "supports stroke_gray" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.stroke_gray(0.5)
        result.should be(page)
      end
    end

    it "supports fill_gray" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.fill_gray(0.5)
        result.should be(page)
      end
    end

    it "supports stroke_cmyk" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.stroke_cmyk(0.0, 1.0, 1.0, 0.0)
        result.should be(page)
      end
    end

    it "supports fill_cmyk" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.fill_cmyk(1.0, 0.0, 0.0, 0.0)
        result.should be(page)
      end
    end

    it "supports stroke_color_space" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.stroke_color_space("DeviceRGB")
        result.should be(page)
      end
    end

    it "supports fill_color_space" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.fill_color_space("DeviceCMYK")
        result.should be(page)
      end
    end
  end

  describe "transformations" do
    it "supports transform" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.transform(1, 0, 0, 1, 100, 50)
        result.should be(page)
      end
    end

    it "supports translate" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.translate(100, 50)
        result.should be(page)
      end
    end

    it "supports scale with two arguments" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.scale(2.0, 2.0)
        result.should be(page)
      end
    end

    it "supports scale with one argument" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.scale(2.0)
        result.should be(page)
      end
    end

    it "supports rotate" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rotate(45)
        result.should be(page)
      end
    end

    it "supports skew" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.skew(15, 0)
        result.should be(page)
      end
    end
  end

  describe "extended graphics state" do
    it "supports opacity" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.opacity(0.5)
        result.should be(page)
      end
    end

    it "supports stroke_opacity" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.stroke_opacity(0.8)
        result.should be(page)
      end
    end

    it "supports set_opacity with both values" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.set_opacity(fill: 0.5, stroke: 0.8)
        result.should be(page)
      end
    end

    it "supports blend_mode with enum" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.blend_mode(PDF::Content::GraphicsState::BlendMode::Multiply)
        result.should be(page)
      end
    end

    it "supports blend_mode with symbol" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.blend_mode(:multiply)
        result.should be(page)
      end
    end

    it "raises for unknown blend_mode" do
      doc = PDF::Document.new
      doc.page do |page|
        expect_raises(ArgumentError, /Unknown blend mode/) do
          page.blend_mode(:unknown)
        end
      end
    end

    it "supports set_graphics_state with ExtGState" do
      doc = PDF::Document.new
      doc.page do |page|
        gs = PDF::Objects::ExtGState.new
        gs.fill_opacity = 0.5
        gs.blend_mode = PDF::Content::GraphicsState::BlendMode::Screen
        result = page.set_graphics_state(gs)
        result.should be(page)
      end
    end
  end

  describe "shape helpers" do
    it "supports circle" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.circle(200, 300, 50).fill
        result.should be(page)
      end
    end

    it "supports ellipse" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.ellipse(200, 300, 80, 40).stroke
        result.should be(page)
      end
    end

    it "supports polygon" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.polygon([{100, 100}, {150, 200}, {200, 100}]).fill_stroke
        result.should be(page)
      end
    end

    it "supports polygon with empty points" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.polygon([] of Tuple(Int32, Int32))
        result.should be(page)
      end
    end

    it "supports rounded_rectangle" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.rounded_rectangle(100, 100, 200, 100, 10).fill
        result.should be(page)
      end
    end

    it "supports rounded_rectangle with large radius (clamped)" do
      doc = PDF::Document.new
      doc.page do |page|
        # Radius is clamped to half of minimum dimension
        result = page.rounded_rectangle(100, 100, 100, 50, 100).stroke
        result.should be(page)
      end
    end

    it "supports arc" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.arc(200, 200, 50, 0, 90).stroke
        result.should be(page)
      end
    end

    it "supports arc_with_radii (elliptical arc)" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.arc_with_radii(200, 200, 80, 40, 0, 180).stroke
        result.should be(page)
      end
    end

    it "supports line helper" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.line({100, 100}, {200, 200}).stroke
        result.should be(page)
      end
    end
  end

  describe "integration" do
    it "creates PDF with complex graphics" do
      doc = PDF::Document.new
      doc.page do |page|
        # Draw background
        page.fill_color(:white)
        page.rectangle(0, 0, 612, 792).fill

        # Draw a rotated rectangle with transparency
        page.save_graphics_state do
          page.translate(200, 400)
          page.rotate(45)
          page.opacity(0.5)
          page.fill_color("#FF5500")
          page.rectangle(-50, -50, 100, 100)
          page.fill
        end

        # Draw a circle with stroke
        page.stroke_color(:blue)
        page.line_width(3)
        page.dash([5, 3])
        page.circle(400, 400, 60)
        page.stroke

        # Draw a polygon
        page.fill_color(:green)
        page.stroke_color(:black)
        page.solid
        page.polygon([{100, 100}, {150, 200}, {200, 100}])
        page.fill_stroke
      end

      # This should not raise
      bytes = doc.to_slice
      bytes.size.should be > 0
    end
  end
end
