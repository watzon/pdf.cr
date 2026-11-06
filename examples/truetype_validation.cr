require "../src/pdf"

# TrueType Font Validation Example
# This generates a PDF that tests all Phase 2 TrueType font features

font_path = File.join(__DIR__, "..", "spec", "fixtures", "fonts", "DejaVuSans.ttf")

unless File.exists?(font_path)
  puts "Error: Font file not found at #{font_path}"
  puts "Run the tests first to download the font, or provide your own .ttf file"
  exit 1
end

pdf = PDF::Document.new
pdf.title = "TrueType Font Validation"
pdf.author = "pdf.cr Phase 2 Test"

# Load the TrueType font
dejavu = pdf.load_font(font_path)

# =========================================
# Page 1: Basic TrueType Functionality
# =========================================
pdf.page do |page|
  page.font dejavu, size: 24
  page.text "Page 1: Basic TrueType Features", at: {72, 750}

  # Feature: Font name with subset prefix
  page.font dejavu, size: 14
  page.text "Feature: Font Subset Naming", at: {72, 700}
  page.font dejavu, size: 11
  page.text "Font name: #{dejavu.name}", at: {90, 680}
  page.text "Base name: #{dejavu.base_name}", at: {90, 665}

  # Feature: Various font sizes
  page.font dejavu, size: 14
  page.text "Feature: Multiple Font Sizes", at: {72, 630}

  page.font dejavu, size: 8
  page.text "8pt: The quick brown fox jumps over the lazy dog", at: {90, 610}
  page.font dejavu, size: 10
  page.text "10pt: The quick brown fox jumps over the lazy dog", at: {90, 595}
  page.font dejavu, size: 12
  page.text "12pt: The quick brown fox jumps over the lazy dog", at: {90, 578}
  page.font dejavu, size: 14
  page.text "14pt: The quick brown fox jumps", at: {90, 558}
  page.font dejavu, size: 18
  page.text "18pt: Quick brown fox", at: {90, 535}
  page.font dejavu, size: 24
  page.text "24pt: Fox jumps", at: {90, 505}

  # Feature: Full alphabet
  page.font dejavu, size: 14
  page.text "Feature: Full ASCII Set", at: {72, 460}
  page.font dejavu, size: 11
  page.text "ABCDEFGHIJKLMNOPQRSTUVWXYZ", at: {90, 440}
  page.text "abcdefghijklmnopqrstuvwxyz", at: {90, 425}
  page.text "0123456789", at: {90, 410}
  page.text "!@#$%^&*()_+-=[]{}|;':\",./<>?", at: {90, 395}

  # Feature: Mix with Type1 font
  page.font dejavu, size: 14
  page.text "Feature: Mixed Font Usage", at: {72, 360}

  page.font "Helvetica", size: 11
  page.text "Type1 Helvetica: Standard PDF font", at: {90, 340}
  page.font dejavu, size: 11
  page.text "TrueType DejaVu: Custom embedded font", at: {90, 325}
  page.font "Times-Roman", size: 11
  page.text "Type1 Times: Another standard font", at: {90, 310}
  page.font dejavu, size: 11
  page.text "Back to DejaVu Sans!", at: {90, 295}
end

# =========================================
# Page 2: Unicode Support
# =========================================
pdf.page do |page|
  page.font dejavu, size: 24
  page.text "Page 2: Unicode Support", at: {72, 750}

  # Latin Extended
  page.font dejavu, size: 14
  page.text "Latin Extended:", at: {72, 700}
  page.font dejavu, size: 12
  page.text "àáâãäåæçèéêëìíîï ðñòóôõöøùúûüýþÿ", at: {90, 680}
  page.text "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏ ÐÑÒÓÔÕÖØÙÚÛÜÝÞ", at: {90, 662}

  # Cyrillic
  page.font dejavu, size: 14
  page.text "Cyrillic (Russian):", at: {72, 630}
  page.font dejavu, size: 12
  page.text "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ", at: {90, 610}
  page.text "абвгдеёжзийклмнопрстуфхцчшщъыьэюя", at: {90, 592}
  page.text "Привет мир! Здравствуйте!", at: {90, 574}

  # Greek
  page.font dejavu, size: 14
  page.text "Greek:", at: {72, 540}
  page.font dejavu, size: 12
  page.text "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ", at: {90, 520}
  page.text "αβγδεζηθικλμνξοπρστυφχψω", at: {90, 502}
  page.text "Γειά σου, Κόσμε!", at: {90, 484}

  # Symbols
  page.font dejavu, size: 14
  page.text "Mathematical & Technical Symbols:", at: {72, 450}
  page.font dejavu, size: 12
  page.text "∀ ∃ ∅ ∈ ∉ ∋ ∏ ∑ √ ∞ ∠ ∧ ∨ ∩ ∪ ∫", at: {90, 430}
  page.text "≤ ≥ ≠ ≈ ≡ ⊂ ⊃ ⊆ ⊇ ⊥ ⊕ ⊗ ⊙", at: {90, 412}
  page.text "← → ↑ ↓ ↔ ↕ ⇐ ⇒ ⇑ ⇓ ⇔", at: {90, 394}

  # Currency & Common Symbols
  page.font dejavu, size: 14
  page.text "Currency & Common Symbols:", at: {72, 360}
  page.font dejavu, size: 12
  page.text "$ € £ ¥ ¢ © ® ™ § ¶ † ‡ • ‰ ‱", at: {90, 340}
  page.text "° ′ ″ ∞ ∂ ∇ ¼ ½ ¾ ⅓ ⅔ ⅛ ⅜ ⅝ ⅞", at: {90, 322}

  # Box Drawing
  page.font dejavu, size: 14
  page.text "Box Drawing Characters:", at: {72, 285}
  page.font dejavu, size: 12
  page.text "┌───┬───┐", at: {90, 265}
  page.text "│ A │ B │", at: {90, 250}
  page.text "├───┼───┤", at: {90, 235}
  page.text "│ C │ D │", at: {90, 220}
  page.text "└───┴───┘", at: {90, 205}
end

# =========================================
# Page 3: Font Metrics & Text Measurement
# =========================================
pdf.page do |page|
  page.font dejavu, size: 24
  page.text "Page 3: Font Metrics", at: {72, 750}

  # Display metrics
  page.font dejavu, size: 14
  page.text "Font Metrics (1/1000 em units):", at: {72, 700}
  page.font dejavu, size: 11

  test_chars = ['A', 'W', 'i', 'l', 'M', 'm', ' ']
  y = 680
  test_chars.each do |char|
    width = dejavu.glyph_width(char)
    page.text "'#{char}' width: #{width}", at: {90, y}
    y -= 18
  end

  # String width calculation
  page.font dejavu, size: 14
  page.text "String Width Calculation:", at: {72, y - 20}
  page.font dejavu, size: 11

  test_strings = [
    "Hello",
    "World",
    "The quick brown fox",
  ]
  y = y - 45
  test_strings.each do |str|
    width = dejavu.string_width(str, 12.0)
    page.text "\"#{str}\" at 12pt: #{width.round(2)} points", at: {90, y}
    y -= 18
  end

  # Visual width verification
  page.font dejavu, size: 14
  page.text "Visual Width Verification:", at: {72, y - 20}
  page.font dejavu, size: 11

  test_str = "TESTING"
  calc_width = dejavu.string_width(test_str, 12.0)
  y = y - 45

  page.text "Text: \"#{test_str}\" | Calculated width: #{calc_width.round(2)}pt", at: {90, y}

  # Draw the text and a box around its calculated dimensions
  text_y = y - 25
  page.font dejavu, size: 12
  page.text test_str, at: {90, text_y}

  # Draw box to show measured width
  page.stroke_color 1.0, 0.0, 0.0
  page.line_width 0.5
  page.move_to 90, text_y - 3
  page.line_to 90 + calc_width, text_y - 3
  page.stroke

  page.font dejavu, size: 9
  page.text "(red line shows calculated width)", at: {90, text_y - 15}
end

# =========================================
# Page 4: Subsetting Demonstration
# =========================================
pdf.page do |page|
  page.font dejavu, size: 24
  page.text "Page 4: Font Subsetting", at: {72, 750}

  page.font dejavu, size: 11
  page.text "The font embedded in this PDF is subsetted to include only glyphs used.", at: {72, 710}
  page.text "Original DejaVu Sans: ~741 KB", at: {72, 692}

  # Get subset size
  subset_size = dejavu.subset_data.size
  page.text "Subset size: #{(subset_size / 1024.0).round(2)} KB", at: {72, 674}

  page.font dejavu, size: 14
  page.text "Subset includes glyphs for:", at: {72, 640}
  page.font dejavu, size: 11
  page.text "• All ASCII letters, numbers, and punctuation", at: {90, 620}
  page.text "• Extended Latin characters (àáâãäå...)", at: {90, 602}
  page.text "• Cyrillic alphabet (used in Russian text)", at: {90, 584}
  page.text "• Greek alphabet", at: {90, 566}
  page.text "• Mathematical and technical symbols", at: {90, 548}
  page.text "• Box drawing characters", at: {90, 530}
  page.text "• Common symbols (©, ®, ™, currencies, etc.)", at: {90, 512}

  # CIDToGIDMap explanation
  page.font dejavu, size: 14
  page.text "Technical Details:", at: {72, 470}
  page.font dejavu, size: 11
  page.text "• Font type: CIDFontType2 (TrueType outlines)", at: {90, 450}
  page.text "• Encoding: Identity-H (glyph IDs as CIDs)", at: {90, 432}
  page.text "• CIDToGIDMap: Maps original to subset glyph IDs", at: {90, 414}
  page.text "• ToUnicode: Enables text extraction from PDF", at: {90, 396}
  page.text "• FontFile2: Contains the subset TrueType data", at: {90, 378}
end

output_path = "examples/truetype_validation.pdf"
pdf.save(output_path)

puts "Generated #{output_path}"
puts "PDF has #{pdf.pages.size} pages demonstrating Phase 2 TrueType features:"
puts "  - Page 1: Basic TrueType functionality and font mixing"
puts "  - Page 2: Unicode support (Latin, Cyrillic, Greek, symbols)"
puts "  - Page 3: Font metrics and text measurement"
puts "  - Page 4: Font subsetting demonstration"
puts ""
puts "Subset font size: #{(dejavu.subset_data.size / 1024.0).round(2)} KB (original: ~741 KB)"
