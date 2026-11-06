# pdf.cr

[![CI](https://github.com/watzon/pdf/actions/workflows/ci.yml/badge.svg)](https://github.com/watzon/pdf/actions/workflows/ci.yml)
[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

A pure Crystal library for PDF generation and parsing.

PDF.cr is a high-performance, pure-Crystal implementation of the PDF 1.7 (ISO 32000-1) specification. It is designed to be a reliable, easy-to-use alternative to C-based libraries like libharu, providing a native Crystal experience for generating and (eventually) parsing PDF documents.

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [API](#api)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

## Background

The motivation behind `pdf.cr` was to create a PDF generation library for the Crystal ecosystem that doesn't rely on external C dependencies. While libraries like `libharu` are powerful, they can be difficult to manage in containerized environments or cross-platform builds. By being written in pure Crystal, `pdf.cr` ensures maximum portability and ease of installation, while leveraging Crystal's performance and type safety.

## Install

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  pdf:
    github: watzon/pdf
```

Then run `shards install`.

## Usage

### Quick Start

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

### Standard Fonts (Type1)

All 14 standard PDF fonts are built-in:

- Helvetica, Helvetica-Bold, Helvetica-Oblique, Helvetica-BoldOblique
- Times-Roman, Times-Bold, Times-Italic, Times-BoldItalic  
- Courier, Courier-Bold, Courier-Oblique, Courier-BoldOblique
- Symbol, ZapfDingbats

### TrueType Fonts

Load any TrueType (.ttf) font for full Unicode support:

```crystal
pdf = PDF::Document.new

# Load a TrueType font
my_font = pdf.load_font("path/to/DejaVuSans.ttf")

pdf.page do |page|
  # Use the TrueType font
  page.font my_font, size: 16
  page.text "English: Hello, World!", at: {72, 720}
  page.text "Russian: Привет, мир!", at: {72, 690}
  page.text "Greek: Γειά σου, Κόσμε!", at: {72, 660}
  page.text "Symbols: © ® ™ € £ ¥ → ←", at: {72, 630}
  
  # You can mix TrueType and Type1 fonts
  page.font "Helvetica", size: 12
  page.text "Back to Helvetica", at: {72, 590}
end

pdf.save("unicode_text.pdf")
```

**Features:**
- Full Unicode support (BMP and supplementary planes)
- Automatic font subsetting (only used glyphs are embedded)
- Proper glyph metrics for accurate text positioning
- ToUnicode mapping for text extraction from generated PDFs

### Formatted Text

`page.formatted_text_box` wraps styled text in a box. Each fragment has its own styles, color, font and size. Text that does not fit is returned.

```crystal
remaining = page.formatted_text_box(
  [
    {text: "Hello ", styles: [] of Symbol},
    {text: "world", styles: [:bold]},
    {text: "!", styles: [:italic], color: "FF0000"},
  ],
  at: {72, 720}, width: 400, height: 200,
  align: :justify,     # :left, :center, :right, :justify
  overflow: :truncate, # :truncate, :expand, :shrink_to_fit
)
```

A string argument is parsed as inline markup, as in Prawn. The tags are `<b>`, `<strong>`, `<i>`, `<em>`, `<u>`, `<strikethrough>`, `<sub>`, `<sup>`, `<color rgb="FF0000">`, `<font name="Courier" size="10">` and `<br>`. A font size must be a positive number. Use `&lt;`, `&gt;` and `&amp;` for `<`, `>` and `&`. `PDF::Text::Formatted::Parser.format` returns the fragments.

```crystal
page.formatted_text_box(%(Plain, <b>bold</b>, <color rgb="0000FF">blue</color>), at: {72, 720}, width: 400)
```

To know where the text ended, use the block form. The `cursor` of the result is the y coordinate below the last line:

```crystal
page.formatted_text_box("First paragraph.", at: {72, 720}, width: 400) do |result|
  page.formatted_text_box("Second paragraph.", at: {72, result.cursor - 6}, width: 400)
end
```

To continue text in other boxes, use a flow. `page.formatted_text_flow` fills boxes on one page in order. `pdf.formatted_text_flow` adds pages until all text is printed, and yields each new page (for example to draw a header):

```crystal
page.formatted_text_flow(long_text, boxes: [
  {at: {72, 720}, width: 220, height: 600},
  {at: {320, 720}, width: 220, height: 600},
])

result = pdf.formatted_text_flow(chapter, at: {72, 720}, width: 468, height: 648) do |new_page|
  new_page.font("Helvetica", size: 9)
  new_page.text("Chapter 1", at: {72, 750})
end
result.page   # the last page
result.cursor # where the next element can start on it
```

For bold and italic text in a TrueType font, register a font family. Use the family name as `font_name:` or as the `:font` of a fragment. A missing variant falls back to the closest registered one:

```crystal
pdf.font_family("DejaVu",
  normal: "fonts/DejaVuSans.ttf",
  bold: "fonts/DejaVuSans-Bold.ttf",
  italic: "fonts/DejaVuSans-Oblique.ttf",
  bold_italic: "fonts/DejaVuSans-BoldOblique.ttf")

page.formatted_text_box("DejaVu <b>bold</b> <i>italic</i>", at: {72, 720}, width: 400, font_name: "DejaVu")
```

Line placement uses fixed ratios of the font size by default (ascender 0.8, descender 0.2, line height 1.2). Pass `metrics: :font` to use the ascender, descender and line gap of each font instead. For Type1 fonts these come from the Adobe AFM files. For TrueType fonts they come from the OS/2 and `hhea` tables.

See `examples/formatted_text.cr` for a complete example.

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

### SVG

`page.svg` draws an SVG document as vector graphics. `at` is the top-left
corner on the page. Give `width`, `height` or both to scale it.

```crystal
pdf.page do |page|
  page.svg(File.read("diagram.svg"), at: {72, 720}, width: 400)
end
```

Supported:

- Shapes: `rect` (with `rx` and `ry`), `circle`, `ellipse`, `line`,
  `polyline`, `polygon` and `path` (all commands, including arcs).
- Structure: `g`, `defs`, `use` (with `x` and `y`, and `symbol` or `svg`
  targets), nested `svg` viewports, `viewBox`, `preserveAspectRatio`
  (all alignments with `meet` or `slice`, and `none`) and `transform`.
- Styling: presentation attributes, `style=""`, `<style>` sheets with
  type, class, id and attribute selectors (ranked by specificity, with
  `!important`), inheritance and `currentColor`.
- Paint: colors, `linearGradient` and `radialGradient` (including
  `stop-opacity`), `opacity`, `fill-opacity`, `stroke-opacity`,
  `fill-rule`, `stroke-width`, `stroke-dasharray`, `stroke-dashoffset`,
  `stroke-linecap`, `stroke-linejoin` and `stroke-miterlimit`.
- `clipPath`, in user space or bounding-box units.
- Text: `text` and `tspan` with `x`, `y`, `dx` and `dy`, `text-anchor`,
  `font-size`, `font-weight`, `font-style` and `font-family`. Families map
  to the standard 14 fonts (serif to Times, monospace to Courier, others
  to Helvetica).

This is a subset of SVG, not a full implementation. Known limits:

- `opacity` on a group applies to each child shape on its own.
- Gradient strokes and gradient text assume that the page has its default
  transformation when you call `page.svg`.
- `spreadMethod` reflect and repeat draw as pad.
- Text uses only the standard 14 fonts (no embedded fonts), so characters
  outside their encoding do not show. Text is filled but never stroked,
  and `textPath`, `letter-spacing` and vertical text are not supported.
- Text inside a `clipPath` is ignored. A clip path that holds only text
  hides the clipped element.
- CSS supports only the selectors listed above. Pseudo-classes, sibling
  combinators and at-rules (`@media`, `@import`, `@font-face`) are ignored.
- `image`, `mask`, `pattern`, `marker`, `filter`, `foreignObject` and
  `textPath` are skipped, and the renderer records a warning
  (`page.svg(...).warnings`).
- To bound the work on hostile input, nested `use` references stop after
  32 levels or 50,000 referenced elements (with a warning).

See `examples/svg_demo.cr` for a sample of each feature.

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

## API

### PDF::Document

The `PDF::Document` class is the main entry point for creating and managing PDF files. It handles the document-wide resources, metadata, and page management.

- `initialize`: Creates a new document.
- `page(size, orientation, &block)`: Adds a new page to the document and yields a `PDF::Page` object.
- `load_font(path)`: Loads a TrueType font for use in the document.
- `font_family(name, normal:, bold:, italic:, bold_italic:)`: Registers the style variants of a font for formatted text.
- `formatted_text_flow(fragments, at:, width:, height:)`: Flows formatted text from page to page.
- `save(path)`: Serializes the document and writes it to a file.
- `to_slice`: Returns the serialized document as a `Bytes` slice.

### PDF::Page

The `PDF::Page` class represents a single page and provides a high-level DSL for drawing content.

- `font(name_or_font, size)`: Sets the current font and size.
- `text(string, at)`: Draws text at the specified coordinates.
- `formatted_text_box(fragments_or_markup, at:, width:)`: Wraps styled text in a box and returns the text that does not fit.
- `formatted_text_flow(fragments_or_markup, boxes:)`: Flows formatted text through boxes on the page.
- `rectangle(x, y, width, height)`: Defines a rectangular path.
- `move_to(x, y)` / `line_to(x, y)`: Path construction methods.
- `stroke`, `fill`, `fill_stroke`: Path painting operations.
- `save_graphics_state(&block)`: Saves the current graphics state, executes the block, and restores it.
- `svg(data, at, width, height)`: Draws an SVG document and returns the `PDF::SVG::Renderer`.
- `register_shading(dict)` / `shade(key)`: Registers a shading resource and paints it.
- `register_pattern(dict)` / `fill_pattern(key)` / `stroke_pattern(key)`: Registers a pattern resource and uses it as paint.

## Maintainers

- [Chris Watson](https://github.com/watzon)

## Contributing

PRs accepted.

Small note: If editing the README, please conform to the [standard-readme](https://github.com/RichardLitt/standard-readme) specification.

1. Fork it (<https://github.com/watzon/pdf/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT © Chris Watson
