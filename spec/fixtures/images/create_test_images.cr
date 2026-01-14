# Run this file to generate test images
# crystal run spec/fixtures/images/create_test_images.cr

require "stumpy_png"
include StumpyPNG

# Create a simple RGB test image (100x100 red/blue gradient)
def create_rgb_test
  canvas = Canvas.new(100, 100)
  (0...100).each do |x|
    (0...100).each do |y|
      r = ((x / 100.0) * 255).to_u16 << 8
      g = 0_u16
      b = ((y / 100.0) * 255).to_u16 << 8
      canvas[x, y] = RGBA.new(r, g, b)
    end
  end
  StumpyPNG.write(canvas, "spec/fixtures/images/test_rgb.png", bit_depth: 8, color_type: :rgb)
  puts "Created test_rgb.png"
end

# Create a PNG with alpha channel (circle with transparency)
def create_rgba_test
  canvas = Canvas.new(100, 100)
  center_x = 50
  center_y = 50
  radius = 40

  (0...100).each do |x|
    (0...100).each do |y|
      dx = x - center_x
      dy = y - center_y
      distance = Math.sqrt(dx * dx + dy * dy)

      if distance <= radius
        # Inside circle: red with varying alpha based on distance
        alpha = ((1.0 - distance / radius) * 65535).to_u16
        canvas[x, y] = RGBA.new(65535_u16, 0_u16, 0_u16, alpha)
      else
        # Outside: transparent
        canvas[x, y] = RGBA.new(0_u16, 0_u16, 0_u16, 0_u16)
      end
    end
  end
  StumpyPNG.write(canvas, "spec/fixtures/images/test_rgba.png", bit_depth: 8, color_type: :rgb_alpha)
  puts "Created test_rgba.png"
end

# Create a grayscale test image
def create_gray_test
  canvas = Canvas.new(100, 100)
  (0...100).each do |x|
    (0...100).each do |y|
      gray = ((x / 100.0) * 65535).to_u16
      canvas[x, y] = RGBA.new(gray, gray, gray)
    end
  end
  StumpyPNG.write(canvas, "spec/fixtures/images/test_gray.png", bit_depth: 8, color_type: :grayscale)
  puts "Created test_gray.png"
end

create_rgb_test
create_rgba_test
create_gray_test
puts "Done!"
