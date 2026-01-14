# Run this to generate sample PDFs with images
# crystal run examples/images_demo.cr

require "../src/pdf"

# Demo 1: JPEG images
puts "Creating JPEG demo PDF..."
doc = PDF::Document.new
doc.title = "JPEG Image Demo"
doc.author = "pdf.cr"

jpeg_rgb = PDF::Images::JPEG.load("spec/fixtures/images/test_rgb.jpg")
jpeg_gray = PDF::Images::JPEG.load("spec/fixtures/images/test_gray.jpg")

doc.page do |page|
  page.font "Helvetica-Bold", size: 24
  page.text "JPEG Image Demo", at: {72, 750}

  page.font "Helvetica", size: 12
  page.text "RGB JPEG (100x100) - Original size:", at: {72, 700}
  page.image jpeg_rgb, at: {72, 580}

  page.text "RGB JPEG - Width: 200px:", at: {200, 700}
  page.image jpeg_rgb, at: {200, 480}, width: 200

  page.text "Grayscale JPEG:", at: {72, 450}
  page.image jpeg_gray, at: {72, 330}

  page.text "Scale: 0.5:", at: {200, 450}
  page.image jpeg_gray, at: {200, 330}, scale: 0.5

  page.text "Width: 150, Height: 50 (distorted):", at: {72, 280}
  page.image jpeg_rgb, at: {72, 200}, width: 150, height: 50
end

doc.save("examples/jpeg_demo.pdf")
puts "  Saved: examples/jpeg_demo.pdf"

# Demo 2: PNG images with transparency
puts "Creating PNG demo PDF..."
doc = PDF::Document.new
doc.title = "PNG Image Demo"
doc.author = "pdf.cr"

png_rgb = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")
png_rgba = PDF::Images::PNG.load("spec/fixtures/images/test_rgba.png")

doc.page do |page|
  page.font "Helvetica-Bold", size: 24
  page.text "PNG Image Demo", at: {72, 750}

  page.font "Helvetica", size: 12

  # RGB PNG
  page.text "RGB PNG (no transparency):", at: {72, 700}
  page.image png_rgb, at: {72, 580}, width: 150

  # RGBA PNG with background to show transparency
  page.text "RGBA PNG with transparency:", at: {72, 520}
  page.text "(red gradient circle on blue background)", at: {72, 505}

  # Draw blue background
  page.fill_color(0.2, 0.4, 0.8)
  page.rectangle(72, 300, 200, 200)
  page.fill

  # Draw the transparent image on top
  page.image png_rgba, at: {72, 300}, width: 200

  # Same image without background
  page.text "Same RGBA PNG without background:", at: {300, 520}
  page.image png_rgba, at: {300, 300}, width: 200
end

doc.save("examples/png_demo.pdf")
puts "  Saved: examples/png_demo.pdf"

# Demo 3: Mixed content with text, graphics, and images
puts "Creating mixed content demo PDF..."
doc = PDF::Document.new
doc.title = "Mixed Content Demo"
doc.author = "pdf.cr"

doc.page do |page|
  page.font "Helvetica-Bold", size: 28
  page.text "PDF Generation with Crystal", at: {72, 750}

  page.font "Helvetica", size: 14
  page.text "This PDF demonstrates text, graphics, and images.", at: {72, 710}

  # Section 1: Graphics
  page.font "Helvetica-Bold", size: 16
  page.text "1. Vector Graphics", at: {72, 660}

  # Draw colored rectangles
  page.fill_color(1.0, 0.3, 0.3)
  page.rectangle(72, 590, 80, 50)
  page.fill

  page.fill_color(0.3, 1.0, 0.3)
  page.rectangle(162, 590, 80, 50)
  page.fill

  page.fill_color(0.3, 0.3, 1.0)
  page.rectangle(252, 590, 80, 50)
  page.fill

  # Section 2: Images
  page.font "Helvetica-Bold", size: 16
  page.fill_color(0, 0, 0) # Reset to black for text
  page.text "2. Embedded Images", at: {72, 560}

  jpeg = PDF::Images::JPEG.load("spec/fixtures/images/test_rgb.jpg")
  png = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")

  page.font "Helvetica", size: 10
  page.text "JPEG:", at: {72, 520}
  page.image jpeg, at: {72, 400}, width: 100

  page.text "PNG:", at: {200, 520}
  page.image png, at: {200, 400}, width: 100

  # Transparency demo
  page.text "PNG with alpha:", at: {330, 520}
  page.fill_color(0.8, 0.8, 0.2) # Yellow background
  page.rectangle(330, 400, 120, 120)
  page.fill
  png_alpha = PDF::Images::PNG.load("spec/fixtures/images/test_rgba.png")
  page.image png_alpha, at: {340, 410}, width: 100

  # Section 3: Footer
  page.fill_color(0.5, 0.5, 0.5)
  page.font "Helvetica-Oblique", size: 10
  page.text "Generated with pdf.cr - A pure Crystal PDF library", at: {72, 50}
end

doc.save("examples/mixed_demo.pdf")
puts "  Saved: examples/mixed_demo.pdf"

# Demo 4: Multi-page with images
puts "Creating multi-page demo PDF..."
doc = PDF::Document.new
doc.title = "Multi-Page Image Demo"

images = [
  {"JPEG RGB", PDF::Images::JPEG.load("spec/fixtures/images/test_rgb.jpg")},
  {"JPEG Grayscale", PDF::Images::JPEG.load("spec/fixtures/images/test_gray.jpg")},
  {"PNG RGB", PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")},
  {"PNG RGBA", PDF::Images::PNG.load("spec/fixtures/images/test_rgba.png")},
]

images.each_with_index do |(name, img), i|
  doc.page do |page|
    page.font "Helvetica-Bold", size: 24
    page.text "Page #{i + 1}: #{name}", at: {72, 750}

    page.font "Helvetica", size: 12
    page.text "Dimensions: #{img.width}x#{img.height}", at: {72, 720}
    page.text "Color Space: #{img.color_space.value}", at: {72, 700}
    page.text "Has Alpha: #{img.has_alpha?}", at: {72, 680}

    # Show image at various sizes
    page.text "Original size:", at: {72, 640}
    page.image img, at: {72, 520}

    page.text "2x scale:", at: {200, 640}
    page.image img, at: {200, 420}, scale: 2.0

    page.text "Width: 300px:", at: {72, 380}
    page.image img, at: {72, 180}, width: 300
  end
end

doc.save("examples/multipage_images.pdf")
puts "  Saved: examples/multipage_images.pdf"

puts "\nDone! Check examples/ for the generated PDFs."
