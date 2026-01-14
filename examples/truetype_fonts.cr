require "../src/pdf"

# TrueType Font Example
# Demonstrates loading and using TrueType fonts with Unicode support

# Path to the font file (DejaVu Sans is a good open-source Unicode font)
font_path = File.join(__DIR__, "..", "spec", "fixtures", "fonts", "DejaVuSans.ttf")

unless File.exists?(font_path)
  puts "Error: Font file not found at #{font_path}"
  puts "Run the tests first to download the font, or provide your own .ttf file"
  exit 1
end

pdf = PDF::Document.new
pdf.title = "TrueType Font Example"
pdf.author = "pdf.cr"

# Load the TrueType font
dejavu = pdf.load_font(font_path)

pdf.page do |page|
  # Title using TrueType font
  page.font dejavu, size: 28
  page.text "TrueType Font Support", at: {72, 720}

  # Subtitle
  page.font dejavu, size: 14
  page.text "pdf.cr now supports TrueType fonts with Unicode and font subsetting", at: {72, 685}

  # Divider line
  page.stroke_color 0.3, 0.3, 0.3
  page.line_width 1
  page.move_to 72, 665
  page.line_to 540, 665
  page.stroke

  # English text
  page.font dejavu, size: 16
  page.text "English: Hello, World!", at: {72, 630}

  # Russian text (Cyrillic)
  page.text "Russian: Привет, мир!", at: {72, 600}

  # Greek text
  page.text "Greek: Γειά σου, Κόσμε!", at: {72, 570}

  # Japanese-style punctuation and symbols
  page.text "Symbols: © ® ™ € £ ¥ • → ← ↑ ↓", at: {72, 540}

  # Mathematical symbols
  page.text "Math: ∑ ∏ ∫ √ ∞ ≤ ≥ ≠ ≈ ∂", at: {72, 510}

  # Mixed content
  page.font dejavu, size: 12
  page.text "DejaVu Sans covers Latin, Cyrillic, Greek, and many symbols.", at: {72, 470}
  page.text "Font subsetting ensures only used glyphs are embedded in the PDF.", at: {72, 450}

  # Feature box
  page.fill_color 0.95, 0.97, 1.0
  page.stroke_color 0.4, 0.5, 0.7
  page.line_width 1
  page.rectangle 72, 320, 468, 110
  page.fill_stroke

  page.font dejavu, size: 11
  page.text "Features:", at: {85, 410}
  page.text "• Full Unicode support (BMP and beyond)", at: {95, 390}
  page.text "• Automatic font subsetting for smaller file sizes", at: {95, 370}
  page.text "• Proper glyph metrics for accurate text positioning", at: {95, 350}
  page.text "• ToUnicode mapping for text extraction", at: {95, 330}

  # Footer with mixed fonts
  page.stroke_color 0.5, 0.5, 0.5
  page.move_to 72, 100
  page.line_to 540, 100
  page.stroke

  page.font "Helvetica", size: 10
  page.text "Generated with pdf.cr - ", at: {72, 80}
  page.font dejavu, size: 10
  page.text "A Pure Crystal PDF Library", at: {185, 80}
end

# Second page: More Unicode examples
pdf.page do |page|
  page.font dejavu, size: 24
  page.text "More Unicode Examples", at: {72, 720}

  page.font dejavu, size: 14

  # Box drawing characters
  page.text "Box Drawing: ┌─┬─┐ │ │ ├─┼─┤ └─┴─┘", at: {72, 670}

  # Arrows
  page.text "Arrows: ← → ↑ ↓ ↔ ↕ ⇐ ⇒ ⇑ ⇓", at: {72, 640}

  # Currency symbols
  page.text "Currency: $ € £ ¥ ¢ ₹ ₽ ₿", at: {72, 610}

  # Fractions
  page.text "Fractions: ½ ⅓ ¼ ⅕ ⅙ ⅛ ⅔ ¾", at: {72, 580}

  # Superscripts and subscripts
  page.text "Super/Sub: ⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹ ₀ ₁ ₂ ₃ ₄ ₅", at: {72, 550}

  # Accented characters
  page.text "Accents: á é í ó ú ñ ü ö ä ß ç ø å", at: {72, 520}

  # Note about font coverage
  page.font dejavu, size: 11
  page.text "Note: Character availability depends on the font's glyph coverage.", at: {72, 470}
  page.text "DejaVu Sans has excellent coverage for European languages and symbols.", at: {72, 450}
end

output_path = "examples/truetype_fonts.pdf"
pdf.save(output_path)
puts "Generated #{output_path}"
puts "Open it in a PDF viewer to see TrueType fonts with Unicode text!"
