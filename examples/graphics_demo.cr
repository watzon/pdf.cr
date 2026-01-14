require "../src/pdf"

# This example demonstrates the Phase 4 graphics and color features
# of the PDF library.

pdf = PDF::Document.new
pdf.title = "Graphics & Color Demo"
pdf.author = "pdf.cr"

# Page 1: Basic Shapes and Colors
pdf.page do |page|
  # Title
  page.font "Helvetica-Bold", size: 24
  page.fill_color(:black)
  page.text "Graphics & Color Demo", at: {72, 720}

  page.font "Helvetica", size: 12
  page.text "Page 1: Basic Shapes and Colors", at: {72, 700}

  # Rectangle with fill and stroke
  page.fill_color("#3498DB") # Hex color
  page.stroke_color(:black)
  page.line_width(2)
  page.rectangle(72, 550, 150, 100)
  page.fill_stroke

  page.text "Rectangle (fill & stroke)", at: {72, 530}

  # Circle
  page.fill_color(:red)
  page.circle(350, 600, 50)
  page.fill

  page.fill_color(:black)
  page.text "Circle (filled)", at: {300, 530}

  # Ellipse (stroke only)
  page.stroke_color("#27AE60") # Green
  page.line_width(3)
  page.ellipse(500, 600, 60, 35)
  page.stroke

  page.fill_color(:black)
  page.text "Ellipse (stroked)", at: {450, 530}

  # Polygon (triangle)
  page.fill_color("#9B59B6") # Purple
  page.stroke_color(:black)
  page.line_width(1)
  page.polygon([{72, 400}, {147, 480}, {222, 400}])
  page.fill_stroke

  page.fill_color(:black)
  page.text "Polygon (triangle)", at: {72, 380}

  # Rounded rectangle
  page.fill_color("#E74C3C") # Red
  page.rounded_rectangle(280, 400, 140, 80, 15)
  page.fill

  page.fill_color(:black)
  page.text "Rounded Rectangle", at: {280, 380}

  # Arc (stroke only)
  page.stroke_color("#F39C12") # Orange
  page.line_width(4)
  page.arc(520, 440, 50, 0, 270)
  page.stroke

  page.fill_color(:black)
  page.text "Arc (270 degrees)", at: {470, 380}

  # Bezier curves
  page.stroke_color("#1ABC9C") # Teal
  page.line_width(2)
  page.move_to(72, 280)
  page.curve_to(122, 350, 222, 200, 272, 280)
  page.stroke

  page.fill_color(:black)
  page.text "Bezier Curve", at: {72, 260}

  # Lines with different styles
  page.stroke_color(:black)
  page.line_width(1)

  # Dash patterns
  page.dash([5, 3])
  page.line({320, 280}, {470, 280})
  page.stroke
  page.text "Dashed line [5, 3]", at: {320, 260}

  page.dash([10, 5, 2, 5])
  page.line({320, 240}, {470, 240})
  page.stroke
  page.text "Dash-dot [10, 5, 2, 5]", at: {320, 220}

  page.solid # Reset to solid
  page.line({320, 200}, {470, 200})
  page.stroke
  page.text "Solid line", at: {320, 180}

  # Color spaces demo
  page.font "Helvetica-Bold", size: 14
  page.fill_color(:black)
  page.text "Color Spaces:", at: {72, 140}

  page.font "Helvetica", size: 10

  # RGB
  page.fill_color(1.0, 0.0, 0.0)
  page.rectangle(72, 100, 30, 30)
  page.fill
  page.fill_color(:black)
  page.text "RGB (red)", at: {110, 110}

  # Grayscale
  page.fill_gray(0.5)
  page.rectangle(200, 100, 30, 30)
  page.fill
  page.fill_color(:black)
  page.text "Gray (0.5)", at: {238, 110}

  # CMYK
  page.fill_cmyk(1.0, 0.0, 0.0, 0.0) # Cyan
  page.rectangle(330, 100, 30, 30)
  page.fill
  page.fill_color(:black)
  page.text "CMYK (cyan)", at: {368, 110}

  # Named color
  page.fill_color(:orange)
  page.rectangle(460, 100, 30, 30)
  page.fill
  page.fill_color(:black)
  page.text "Named (orange)", at: {498, 110}
end

# Page 2: Transformations
pdf.page do |page|
  page.font "Helvetica-Bold", size: 24
  page.fill_color(:black)
  page.text "Transformations", at: {72, 720}

  page.font "Helvetica", size: 12
  page.text "Page 2: Translate, Rotate, Scale, Skew", at: {72, 700}

  # Original rectangle for reference (stroke only)
  page.stroke_color(:gray)
  page.dash([3, 3])
  page.rectangle(100, 500, 80, 50)
  page.stroke
  page.solid

  page.fill_color(:black)
  page.text "Original (dashed)", at: {100, 480}

  # Translated rectangle
  page.save_graphics_state do
    page.translate(150, 50)
    page.fill_color("#3498DB")
    page.rectangle(100, 500, 80, 50)
    page.fill
  end
  page.fill_color(:black)
  page.text "Translated", at: {250, 530}

  # Rotated rectangle
  page.save_graphics_state do
    page.translate(400, 525) # Move origin to center of rotation
    page.rotate(30)
    page.fill_color("#E74C3C")
    page.rectangle(-40, -25, 80, 50) # Draw centered at origin
    page.fill
  end
  page.fill_color(:black)
  page.text "Rotated 30deg", at: {360, 480}

  # Scaled rectangle
  page.save_graphics_state do
    page.translate(100, 350)
    page.scale(1.5, 1.5)
    page.fill_color("#27AE60")
    page.rectangle(0, 0, 80, 50)
    page.fill
  end
  page.fill_color(:black)
  page.text "Scaled 1.5x", at: {100, 330}

  # Skewed rectangle
  page.save_graphics_state do
    page.translate(300, 350)
    page.skew(20, 0)
    page.fill_color("#9B59B6")
    page.rectangle(0, 0, 80, 50)
    page.fill
  end
  page.fill_color(:black)
  page.text "Skewed 20deg", at: {300, 330}

  # Combined transformations
  page.save_graphics_state do
    page.translate(500, 375)
    page.rotate(15)
    page.scale(1.2, 0.8)
    page.fill_color("#F39C12")
    page.rectangle(-40, -25, 80, 50)
    page.fill
  end
  page.fill_color(:black)
  page.text "Combined", at: {460, 330}

  # Nested transformations
  page.font "Helvetica-Bold", size: 14
  page.text "Nested Transformations:", at: {72, 250}

  page.save_graphics_state do
    page.translate(150, 150)
    page.fill_color(:blue)
    page.circle(0, 0, 60)
    page.fill

    page.save_graphics_state do
      page.rotate(45)
      page.fill_color(:red)
      page.rectangle(-30, -30, 60, 60)
      page.fill

      page.save_graphics_state do
        page.scale(0.5, 0.5)
        page.fill_color(:yellow)
        page.circle(0, 0, 40)
        page.fill
      end
    end
  end
  page.font "Helvetica", size: 10
  page.fill_color(:black)
  page.text "Circle -> Rotated Square -> Scaled Circle", at: {72, 70}
end

# Page 3: Transparency and Blend Modes
pdf.page do |page|
  page.font "Helvetica-Bold", size: 24
  page.fill_color(:black)
  page.text "Transparency & Blend Modes", at: {72, 720}

  page.font "Helvetica", size: 12
  page.text "Page 3: Opacity and Compositing", at: {72, 700}

  # Overlapping circles with different opacities
  page.font "Helvetica-Bold", size: 14
  page.text "Opacity:", at: {72, 650}

  # Base circle
  page.fill_color(:red)
  page.circle(150, 580, 60)
  page.fill

  # Overlapping with 50% opacity
  page.save_graphics_state do
    page.opacity(0.5)
    page.fill_color(:blue)
    page.circle(200, 580, 60)
    page.fill
  end

  # Overlapping with 25% opacity
  page.save_graphics_state do
    page.opacity(0.25)
    page.fill_color(:green)
    page.circle(175, 530, 60)
    page.fill
  end

  page.font "Helvetica", size: 10
  page.fill_color(:black)
  page.text "Red: 100%, Blue: 50%, Green: 25%", at: {100, 460}

  # Stroke opacity demo
  page.font "Helvetica-Bold", size: 14
  page.text "Stroke Opacity:", at: {350, 650}

  page.stroke_color(:black)
  page.line_width(10)

  # Full opacity
  page.line({350, 600}, {530, 600})
  page.stroke

  # 75% opacity
  page.save_graphics_state do
    page.stroke_opacity(0.75)
    page.line({350, 570}, {530, 570})
    page.stroke
  end

  # 50% opacity
  page.save_graphics_state do
    page.stroke_opacity(0.5)
    page.line({350, 540}, {530, 540})
    page.stroke
  end

  # 25% opacity
  page.save_graphics_state do
    page.stroke_opacity(0.25)
    page.line({350, 510}, {530, 510})
    page.stroke
  end

  page.font "Helvetica", size: 10
  page.fill_color(:black)
  page.text "100%, 75%, 50%, 25% stroke opacity", at: {350, 480}

  # Blend modes
  page.font "Helvetica-Bold", size: 14
  page.text "Blend Modes:", at: {72, 400}

  blend_modes = [:normal, :multiply, :screen, :overlay, :darken, :lighten]
  x_start = 72

  blend_modes.each_with_index do |mode, i|
    x = x_start + i * 85
    y = 300

    # Background rectangle
    page.fill_color(:yellow)
    page.rectangle(x, y, 70, 70)
    page.fill

    # Overlapping circle with blend mode
    page.save_graphics_state do
      page.blend_mode(mode)
      page.fill_color(:blue)
      page.circle(x + 45, y + 25, 30)
      page.fill
    end

    page.font "Helvetica", size: 8
    page.fill_color(:black)
    page.text mode.to_s, at: {x + 10, y - 15}
  end

  # Clipping demo
  page.font "Helvetica-Bold", size: 14
  page.text "Clipping:", at: {72, 180}

  page.save_graphics_state do
    # Create a circular clipping path
    page.circle(150, 100, 50)
    page.clip!

    # Draw content that will be clipped
    page.fill_color(:red)
    page.rectangle(80, 30, 150, 150)
    page.fill

    page.stroke_color(:blue)
    page.line_width(3)
    (0..10).each do |i|
      page.line({80, 30 + i * 14}, {230, 30 + i * 14})
      page.stroke
    end
  end

  page.font "Helvetica", size: 10
  page.fill_color(:black)
  page.text "Rectangle and lines clipped to circle", at: {80, 35}
end

# Page 4: Line Styles and Graphics State
pdf.page do |page|
  page.font "Helvetica-Bold", size: 24
  page.fill_color(:black)
  page.text "Line Styles & Graphics State", at: {72, 720}

  page.font "Helvetica", size: 12
  page.text "Page 4: Caps, Joins, and State Parameters", at: {72, 700}

  # Line caps demo
  page.font "Helvetica-Bold", size: 14
  page.text "Line Caps:", at: {72, 650}

  page.stroke_color(:black)
  page.line_width(15)

  # Butt cap
  page.line_cap(:butt)
  page.line({100, 600}, {200, 600})
  page.stroke
  page.font "Helvetica", size: 10
  page.text "Butt", at: {220, 595}

  # Round cap
  page.line_cap(:round)
  page.line({100, 560}, {200, 560})
  page.stroke
  page.text "Round", at: {220, 555}

  # Square cap
  page.line_cap(:square)
  page.line({100, 520}, {200, 520})
  page.stroke
  page.text "Square", at: {220, 515}

  # Reference lines showing actual endpoints
  page.stroke_color(:red)
  page.line_width(0.5)
  page.line({100, 630}, {100, 500})
  page.stroke
  page.line({200, 630}, {200, 500})
  page.stroke

  # Line joins demo
  page.font "Helvetica-Bold", size: 14
  page.fill_color(:black)
  page.text "Line Joins:", at: {350, 650}

  page.stroke_color(:black)
  page.line_width(15)
  page.line_cap(:butt)

  # Miter join
  page.line_join(:miter)
  page.move_to(370, 550)
  page.line_to(420, 620)
  page.line_to(470, 550)
  page.stroke
  page.font "Helvetica", size: 10
  page.text "Miter", at: {400, 530}

  # Round join
  page.line_join(:round)
  page.move_to(370, 450)
  page.line_to(420, 520)
  page.line_to(470, 450)
  page.stroke
  page.text "Round", at: {400, 430}

  # Bevel join
  page.line_join(:bevel)
  page.move_to(370, 350)
  page.line_to(420, 420)
  page.line_to(470, 350)
  page.stroke
  page.text "Bevel", at: {400, 330}

  # Miter limit demo
  page.font "Helvetica-Bold", size: 14
  page.fill_color(:black)
  page.text "Miter Limit:", at: {72, 380}

  page.stroke_color(:blue)
  page.line_width(10)
  page.line_join(:miter)

  # Default miter limit (10)
  page.miter_limit(10)
  page.move_to(100, 320)
  page.line_to(130, 360)
  page.line_to(160, 320)
  page.stroke
  page.font "Helvetica", size: 10
  page.fill_color(:black)
  page.text "Limit: 10", at: {100, 300}

  # Lower miter limit (2)
  page.miter_limit(2)
  page.move_to(200, 320)
  page.line_to(230, 360)
  page.line_to(260, 320)
  page.stroke
  page.text "Limit: 2", at: {200, 300}

  # Dash patterns
  page.font "Helvetica-Bold", size: 14
  page.text "Dash Patterns:", at: {72, 250}

  page.stroke_color(:black)
  page.line_width(2)
  page.line_cap(:butt)
  page.miter_limit(10)

  patterns = [
    {[5], "5 on"},
    {[5, 3], "5 on, 3 off"},
    {[10, 5, 2, 5], "Dash-dot"},
    {[1, 3], "Dotted"},
    {[15, 5, 5, 5], "Long dash-dot"},
  ]

  patterns.each_with_index do |(pattern, label), i|
    y = 220 - i * 30
    page.dash(pattern)
    page.line({100, y}, {280, y})
    page.stroke
    page.font "Helvetica", size: 10
    page.fill_color(:black)
    page.text label, at: {290, y - 5}
  end

  page.solid # Reset
end

# Save the document
output_path = "examples/graphics_demo.pdf"
pdf.save(output_path)
puts "Created #{output_path}"
