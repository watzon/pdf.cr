# pdf.cr

A pure Crystal library for PDF generation and parsing.

[![CI](https://github.com/watzon/pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/watzon/pdf/actions/workflows/ci.yml)

## Features

- **Pure Crystal** — No C dependencies, easy installation via shards
- **PDF 1.7 compliant** — Generates modern, standards-compliant PDFs
- **Type1 fonts** — Built-in support for all 14 standard PDF fonts
- **Vector graphics** — Lines, rectangles, colors, and more
- **Compression** — FlateDecode compression for smaller files
- **Multi-page** — Create documents with any number of pages

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     pdf:
       github: watzon/pdf
   ```

2. Run `shards install`

## Quick Start

```crystal
require "pdf"

# Create a new document
pdf = PDF::Document.new
pdf.title = "My Document"
pdf.author = "Crystal Developer"

# Add a page with content
pdf.page do |page|
  page.font "Helvetica-Bold", size: 24
  page.text "Hello, World!", at: {72, 720}
  
  page.font "Helvetica", size: 12
  page.text "This PDF was generated with pdf.cr", at: {72, 690}
end

# Save to file
pdf.save("output.pdf")
```

## Usage

### Page Sizes

```crystal
# Default (US Letter: 612 x 792 points)
pdf.page { |page| }

# Named sizes
pdf.page(size: :a4) { |page| }
pdf.page(size: :legal) { |page| }
pdf.page(size: :tabloid) { |page| }

# Custom size (width x height in points)
pdf.page(width: 400, height: 600) { |page| }

# Landscape orientation
pdf.page(size: :letter, orientation: :landscape) { |page| }
```

### Text

```crystal
pdf.page do |page|
  # Set font (required before drawing text)
  page.font "Helvetica", size: 12
  
  # Draw text at position (x, y from bottom-left)
  page.text "Hello!", at: {72, 720}
  
  # Change font
  page.font "Times-Bold", size: 18
  page.text "Bold Times", at: {72, 680}
end
```

### Available Fonts

All 14 standard Type1 fonts are available:

- Helvetica, Helvetica-Bold, Helvetica-Oblique, Helvetica-BoldOblique
- Times-Roman, Times-Bold, Times-Italic, Times-BoldItalic  
- Courier, Courier-Bold, Courier-Oblique, Courier-BoldOblique
- Symbol, ZapfDingbats

### Graphics

```crystal
pdf.page do |page|
  # Set colors (RGB, values 0.0 to 1.0)
  page.fill_color(1.0, 0.0, 0.0)    # Red fill
  page.stroke_color(0.0, 0.0, 1.0)  # Blue stroke
  
  # Line width
  page.line_width(2)
  
  # Draw a rectangle
  page.rectangle(72, 600, 200, 100)  # x, y, width, height
  page.fill_stroke
  
  # Draw lines
  page.move_to(72, 500)
  page.line_to(272, 500)
  page.stroke
  
  # Graphics state (save/restore)
  page.save_graphics_state do
    page.fill_color(0.0, 1.0, 0.0)
    page.rectangle(100, 400, 50, 50)
    page.fill
  end
  # Original colors are restored here
end
```

### Multiple Pages

```crystal
pdf = PDF::Document.new

3.times do |i|
  pdf.page do |page|
    page.font "Helvetica", size: 18
    page.text "Page #{i + 1}", at: {72, 720}
  end
end

pdf.save("multi_page.pdf")
```

### Getting PDF as Bytes

```crystal
pdf = PDF::Document.new
pdf.page { |page| page.font("Helvetica", size: 12) }

# Get as Bytes for HTTP response, etc.
bytes = pdf.to_slice
```

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full development plan.

### Completed
- [x] PDF object model (Boolean, Number, String, Name, Array, Dictionary, Stream)
- [x] Document structure (Catalog, Pages, Page)
- [x] Type1 font support with glyph metrics
- [x] Basic text rendering
- [x] Vector graphics (lines, rectangles)
- [x] FlateDecode compression
- [x] Multi-page documents

### Coming Soon
- [ ] TrueType/OpenType font embedding with subsetting
- [ ] Image embedding (JPEG, PNG)
- [ ] PDF parsing and text extraction
- [ ] Advanced text layout
- [ ] Annotations and links

## Development

```bash
# Install dependencies
shards install

# Run tests
crystal spec

# Run linter
bin/ameba

# Format code
crystal tool format
```

## Contributing

1. Fork it (<https://github.com/watzon/pdf/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contributors

- [Chris Watson](https://github.com/watzon) - creator and maintainer
