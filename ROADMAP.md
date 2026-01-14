# pdf.cr — Software Design Document & Roadmap

> A pure Crystal library for PDF generation and parsing.

**Target:** PDF 1.7 (ISO 32000-1)  
**Philosophy:** Generation-first with robust, fault-tolerant parsing  
**Dependencies:** Pure Crystal + `stumpy_png` + `stumpy_jpeg`

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [API Design](#api-design)
4. [Implementation Phases](#implementation-phases)
5. [Technical Specifications](#technical-specifications)
6. [Edge Cases & Error Handling](#edge-cases--error-handling)
7. [Testing Strategy](#testing-strategy)
8. [References](#references)

---

## Overview

### Goals

- **Pure Crystal** — No C bindings, maximally portable, easy shard installation
- **Generation-first** — Prioritize creating PDFs over parsing
- **Robust parsing** — Handle malformed real-world PDFs gracefully
- **Idiomatic API** — Block DSL that feels natural to Crystal developers
- **Production-ready** — Suitable for server-side PDF generation

### Non-Goals (Initial Release)

- PDF/A or PDF/X compliance
- Complex text shaping (Arabic, Hebrew, Indic scripts)
- JavaScript or multimedia embedding
- Digital signatures
- Linearization (web-optimized PDFs)

### Dependencies

```yaml
dependencies:
  stumpy_png:
    github: stumpycr/stumpy_png
    version: ~> 5.0
  stumpy_jpeg:
    github: stumpycr/stumpy_jpeg
    version: ~> 1.0
```

---

## Architecture

### Module Structure

```
PDF::
  Document                      # Main entry point, orchestrates generation
  Page                          # Single page abstraction
  
  Object::                      # Low-level PDF object model
    Base                        # Abstract base for all objects
    Indirect                    # Indirect object wrapper (N M obj ... endobj)
    Reference                   # Object reference (N M R)
    Dictionary                  # PDF dictionary (<< /Key Value >>)
    Array                       # PDF array ([ ... ])
    Stream                      # Stream with filters (stream ... endstream)
    Name                        # PDF name (/Name)
    String                      # PDF string (literal or hex)
    Number                      # Integer or real number
    Boolean                     # true/false
    Null                        # null object
  
  Content::                     # Content stream generation
    Canvas                      # High-level drawing context for a page
    Operator                    # Raw PDF operator emission
    Text                        # Text state and operators (BT/ET, Tf, Tj, TJ, Tm, Td)
    Graphics                    # Graphics state (q/Q, cm, w, J, j, M, d)
    Path                        # Path construction (m, l, c, v, y, h, re)
    Color                       # Color operators (g, G, rg, RG, k, K, cs, CS, sc, SC)
  
  Font::                        # Font subsystem
    Base                        # Abstract font interface
    Type1                       # Standard 14 Type1 fonts
    TrueType                    # TrueType/OpenType font handler
    Parser                      # TTF/OTF file parser
    Subset                      # Font subsetting engine
    CMap                        # CMap generation and parsing
    Metrics                     # Glyph widths, bounding boxes
    Encoding                    # WinAnsi, MacRoman, Identity-H
  
  Image::                       # Image subsystem
    Base                        # Abstract image interface
    JPEG                        # JPEG handler (DCT passthrough)
    PNG                         # PNG handler (decode + Flate)
    XObject                     # Image XObject wrapper
  
  Filter::                      # Stream filter codecs
    Base                        # Filter interface
    Flate                       # zlib compression/decompression
    DCT                         # JPEG passthrough (encode only)
    ASCII85                     # ASCII85 encode/decode
    ASCIIHex                    # Hexadecimal encode/decode
    LZW                         # LZW decompression (reading legacy PDFs)
    RunLength                   # Run-length decompression
  
  Parser::                      # PDF reading subsystem
    Lexer                       # Tokenizer for PDF syntax
    Reader                      # High-level document reader
    XRef                        # Cross-reference table/stream parser
    ObjectLoader                # Lazy object loading with caching
    StreamReader                # Stream content extraction
    Recovery                    # Malformed PDF recovery strategies
  
  Writer::                      # PDF writing subsystem
    Serializer                  # Object to bytes serialization
    XRefBuilder                 # Cross-reference table generation
    DocumentBuilder             # Full document assembly
  
  Layout:: (future)             # Text layout engine
    Paragraph                   # Paragraph formatting
    LineBreaker                 # Line breaking algorithm
    TextMeasurer                # Text width calculation
  
  Utils::                       # Utility modules
    Binary                      # Binary I/O helpers
    Encoding                    # Text encoding conversion
    Geometry                    # Points, rectangles, transforms
```

### Object Model

The PDF object model mirrors the PDF specification:

```
PDF Object Types
├── Direct Objects
│   ├── Boolean (true, false)
│   ├── Number (Integer, Real)
│   ├── String (Literal, Hexadecimal)
│   ├── Name (/Identifier)
│   ├── Array [obj1, obj2, ...]
│   ├── Dictionary << /Key value ... >>
│   ├── Stream (dictionary + bytes)
│   └── Null
└── Indirect Objects
    └── N M obj ... endobj (referenced as N M R)
```

### Document Structure

```
PDF Document
├── Header (%PDF-1.7)
├── Body
│   ├── Catalog (document root)
│   │   └── Pages (page tree root)
│   │       ├── Page 1
│   │       │   ├── Contents (content stream)
│   │       │   └── Resources
│   │       │       ├── Font
│   │       │       ├── XObject (images)
│   │       │       └── ExtGState
│   │       ├── Page 2
│   │       └── ...
│   ├── Font objects
│   ├── Image XObjects
│   └── Other resources
├── Cross-Reference Table
└── Trailer
    ├── /Size (object count)
    ├── /Root (catalog reference)
    └── /Info (metadata)
```

---

## API Design

### Document Creation

```crystal
require "pdf"

# Create a new document
pdf = PDF::Document.new

# Add a page with content
pdf.page do |page|
  # Set font and draw text
  page.font "Helvetica", size: 12
  page.text "Hello, Crystal!", at: {72, 720}
  
  # Change font
  page.font "Helvetica-Bold", size: 18
  page.text "PDF Generation", at: {72, 680}
end

# Save to file
pdf.save("output.pdf")

# Or get bytes
bytes = pdf.to_slice
```

### Page Configuration

```crystal
pdf = PDF::Document.new

# Custom page size (width x height in points, 72 points = 1 inch)
pdf.page(width: 612, height: 792) do |page|  # US Letter
  page.text "Letter size page", at: {72, 720}
end

# Predefined sizes
pdf.page(size: :a4) do |page|
  page.text "A4 page", at: {72, 800}
end

# Landscape orientation
pdf.page(size: :letter, orientation: :landscape) do |page|
  page.text "Landscape", at: {72, 540}
end
```

### Text Operations

```crystal
pdf.page do |page|
  # Basic text
  page.font "Helvetica", size: 12
  page.text "Simple text", at: {72, 720}
  
  # Text with options
  page.text "Colored text", at: {72, 700}, color: {1.0, 0.0, 0.0}  # RGB red
  
  # Character spacing
  page.text "S p a c e d", at: {72, 680}, char_spacing: 2
  
  # Word spacing
  page.text "Extra word spacing", at: {72, 660}, word_spacing: 5
  
  # Text scaling (horizontal stretch)
  page.text "Stretched", at: {72, 640}, scale: 150  # 150%
  
  # Text rise (superscript/subscript)
  page.text "Normal", at: {72, 620}
  page.text "super", at: {120, 620}, rise: 5
  page.text "sub", at: {150, 620}, rise: -3
  
  # Rendering mode
  page.text "Outlined", at: {72, 600}, render: :stroke
  page.text "Filled", at: {72, 580}, render: :fill          # default
  page.text "Both", at: {72, 560}, render: :fill_stroke
  page.text "Invisible", at: {72, 540}, render: :invisible  # for searchable OCR
end
```

### Custom Fonts

```crystal
pdf = PDF::Document.new

# Load a TrueType font
open_sans = pdf.load_font("./fonts/OpenSans-Regular.ttf")
open_sans_bold = pdf.load_font("./fonts/OpenSans-Bold.ttf")

pdf.page do |page|
  page.font open_sans, size: 12
  page.text "Custom TrueType font", at: {72, 720}
  
  page.font open_sans_bold, size: 14
  page.text "Bold variant", at: {72, 700}
end

# Font is automatically subsetted to include only used glyphs
pdf.save("custom_fonts.pdf")
```

### Images

```crystal
pdf = PDF::Document.new

# Load images
logo = PDF::Image.load("./images/logo.png")      # PNG with transparency
photo = PDF::Image.load("./images/photo.jpg")    # JPEG

pdf.page do |page|
  # Position and size
  page.image logo, at: {72, 700}, width: 100
  
  # Maintain aspect ratio (specify width OR height)
  page.image photo, at: {72, 500}, width: 400
  
  # Explicit dimensions (may distort)
  page.image photo, at: {72, 200}, width: 200, height: 150
  
  # Scale factor
  page.image logo, at: {300, 700}, scale: 0.5
end

pdf.save("images.pdf")
```

### Vector Graphics

```crystal
pdf.page do |page|
  # Colors (RGB, values 0.0 to 1.0)
  page.stroke_color 0.2, 0.4, 0.8   # Blue stroke
  page.fill_color 0.9, 0.9, 1.0     # Light blue fill
  
  # Line properties
  page.line_width 2
  page.line_cap :round      # :butt, :round, :square
  page.line_join :round     # :miter, :round, :bevel
  page.dash [5, 3]          # 5 on, 3 off
  
  # Rectangle
  page.rectangle 72, 600, 200, 100    # x, y, width, height
  page.fill_stroke
  
  # Lines
  page.move_to 72, 500
  page.line_to 272, 500
  page.line_to 272, 400
  page.stroke
  
  # Bezier curves
  page.move_to 72, 350
  page.curve_to 122, 400, 172, 300, 222, 350   # control1, control2, end
  page.stroke
  
  # Circle (approximated with bezier curves)
  page.circle 400, 600, 50    # center_x, center_y, radius
  page.fill
  
  # Ellipse
  page.ellipse 400, 450, 80, 40   # center_x, center_y, radius_x, radius_y
  page.stroke
  
  # Polygon
  page.polygon [{100, 200}, {150, 280}, {200, 200}]
  page.fill_stroke
  
  # Clipping
  page.save_graphics_state do
    page.rectangle 300, 300, 100, 100
    page.clip
    page.image large_image, at: {250, 250}, width: 200
  end
end
```

### Graphics State

```crystal
pdf.page do |page|
  # Save and restore graphics state
  page.save_graphics_state do
    page.stroke_color 1, 0, 0
    page.line_width 5
    page.move_to(100, 100).line_to(200, 200).stroke
    # State is automatically restored after block
  end
  
  # Transformation matrix
  page.save_graphics_state do
    page.translate 300, 300
    page.rotate 45              # degrees
    page.scale 1.5, 1.5
    page.rectangle 0, 0, 50, 50
    page.stroke
  end
  
  # Transparency
  page.opacity 0.5              # 50% opacity for fill
  page.stroke_opacity 0.8       # 80% opacity for stroke
  page.fill_color 1, 0, 0
  page.rectangle(100, 400, 100, 100).fill
end
```

### Parsing Existing PDFs

```crystal
# Read a PDF file
doc = PDF::Parser.read("input.pdf")

# Document metadata
puts "Title: #{doc.title}"
puts "Author: #{doc.author}"
puts "Pages: #{doc.page_count}"
puts "PDF Version: #{doc.version}"

# Iterate pages
doc.pages.each_with_index do |page, index|
  puts "=== Page #{index + 1} ==="
  puts "Size: #{page.width} x #{page.height}"
  puts page.extract_text
end

# Extract specific page
page = doc.page(0)  # First page (0-indexed)
text = page.extract_text

# Get images from a page (future)
page.images.each do |image|
  image.save("extracted_#{image.name}.png")
end
```

### Low-Level API

```crystal
# Direct content stream manipulation
pdf.page do |page|
  page.content_stream do |cs|
    # Raw PDF operators
    cs.emit "BT"                    # Begin text
    cs.emit "/F1 12 Tf"             # Set font
    cs.emit "72 720 Td"             # Move to position
    cs.emit "(Hello) Tj"            # Show text
    cs.emit "ET"                    # End text
  end
end

# Access internal objects
pdf.catalog      # PDF::Object::Dictionary
pdf.pages_tree   # PDF::Object::Dictionary
```

---

## Implementation Phases

### Phase 1: Core Generation MVP

**Duration:** 3-4 weeks  
**Goal:** Generate valid PDFs with text using built-in fonts

#### 1.1 Project Setup
- [x] Initialize shard structure (`shard.yml`, `src/`, `spec/`)
- [x] Set up CI (GitHub Actions)
- [x] Add stumpy_png and stumpy_jpeg dependencies
- [ ] Create basic README with installation instructions

#### 1.2 PDF Object Model
- [x] `PDF::Object::Base` — Abstract base class with `to_pdf` method
- [x] `PDF::Object::Boolean` — `true` / `false`
- [x] `PDF::Object::Null` — `null`
- [x] `PDF::Object::Number` — Integer and real numbers
  - [x] Handle integer vs float serialization
  - [x] Proper decimal formatting (no trailing zeros)
- [x] `PDF::Object::Name` — `/Name` with proper escaping
  - [x] Escape special characters (#XX format)
  - [x] Handle UTF-8 names (PDF 1.7+)
- [x] `PDF::Object::String` — Literal `(string)` and hex `<hex>`
  - [x] Escape parentheses and backslashes in literal strings
  - [x] Support for UTF-16BE with BOM for Unicode
- [x] `PDF::Object::Array` — `[obj1 obj2 ...]`
- [x] `PDF::Object::Dictionary` — `<< /Key value >>`
- [x] `PDF::Object::Stream` — Dictionary + stream data
  - [x] Length calculation
  - [x] Filter support (FlateDecode)
- [x] `PDF::Object::Reference` — `N M R`
- [x] `PDF::Object::Indirect` — `N M obj ... endobj`

#### 1.3 Document Structure
- [x] `PDF::Document` — Main document class
  - [x] Object ID allocation
  - [x] Resource tracking
- [x] Document Catalog dictionary
- [x] Pages tree structure
  - [x] Page tree node (intermediate)
  - [x] Page leaf node
- [x] Page resources dictionary
- [x] `PDF::Page` — Single page abstraction
  - [x] Size configuration
  - [x] Orientation support
  - [x] MediaBox, CropBox

#### 1.4 Content Stream Basics
- [x] `PDF::Content::Canvas` — High-level drawing context (integrated into Page)
- [x] `PDF::Content::Operator` — Raw operator emission (integrated into Page)
- [x] Text operators
  - [x] `BT` / `ET` — Begin/end text object
  - [x] `Tf` — Set font and size
  - [x] `Td` — Move text position
  - [x] `Tj` — Show string
  - [ ] `TJ` — Show string with positioning
  - [ ] `Tm` — Set text matrix
  - [ ] `T*` — Move to next line
- [x] Content stream compression (FlateDecode)

#### 1.5 Type1 Fonts
- [x] `PDF::Font::Type1` — Standard 14 fonts
  - [x] Helvetica, Helvetica-Bold, Helvetica-Oblique, Helvetica-BoldOblique
  - [x] Times-Roman, Times-Bold, Times-Italic, Times-BoldItalic
  - [x] Courier, Courier-Bold, Courier-Oblique, Courier-BoldOblique
  - [x] Symbol, ZapfDingbats
- [x] Font dictionary structure
- [x] Font resource registration
- [x] Glyph width table (for text measurement)
- [x] WinAnsi encoding support

#### 1.6 Compression
- [x] `PDF::Filter::Flate` — zlib compression
  - [x] Compress streams
  - [x] Set /Filter in stream dictionary
  - [x] Calculate compressed length

#### 1.7 Serialization
- [x] `PDF::Writer::Serializer` — Object to bytes (integrated into objects)
- [x] `PDF::Writer::XRefBuilder` — Cross-reference table
  - [x] Track object byte offsets
  - [x] Generate xref table
- [x] `PDF::Writer::DocumentBuilder` — Full document assembly
  - [x] Header (`%PDF-1.7`)
  - [x] Binary marker (high-bit bytes)
  - [x] Body (all objects)
  - [x] Cross-reference table
  - [x] Trailer dictionary
  - [x] `%%EOF`
- [x] `PDF::Document#save(path)` — Write to file
- [x] `PDF::Document#to_slice` — Get bytes

#### 1.8 Testing
- [x] Unit tests for each object type
- [x] Serialization round-trip tests
- [x] Integration test: generate PDF, verify with external tool
- [ ] Golden tests: compare output to known-good files

### Phase 2: TrueType Fonts ✅ COMPLETE

**Duration:** 3-4 weeks  
**Goal:** Embed any TTF/OTF font with proper Unicode support

#### 2.1 TrueType Parser
- [x] `PDF::Fonts::TrueType::Parser` — TTF/OTF file parser
- [x] Table directory parsing
- [x] Required tables:
  - [x] `head` — Font header (units per em, bounds)
  - [x] `hhea` — Horizontal header (ascent, descent, line gap)
  - [x] `hmtx` — Horizontal metrics (glyph widths)
  - [x] `maxp` — Maximum profile (glyph count)
  - [x] `cmap` — Character to glyph mapping
    - [x] Format 4 (BMP characters)
    - [x] Format 12 (full Unicode)
  - [x] `loca` — Glyph location index
  - [x] `glyf` — Glyph outlines
  - [x] `name` — Naming table (font name, family)
  - [x] `post` — PostScript info
  - [x] `OS/2` — OS/2 and Windows metrics
- [ ] OpenType extensions (optional):
  - [ ] `CFF ` — Compact Font Format (for .otf)

#### 2.2 Font Metrics
- [x] `PDF::Fonts::TrueType::Parser` — Glyph measurements
- [x] Glyph width extraction from `hmtx`
- [x] Ascent, descent from `hhea` or `OS/2`
- [x] Units per em scaling
- [x] Bounding box calculation

#### 2.3 Font Subsetting
- [x] `PDF::Fonts::TrueType::Subsetter` — Font subsetting engine
- [x] Collect used glyphs from text
- [x] Build new `cmap` with only used characters
- [x] Build new `glyf` with only used glyphs
- [x] Update `loca` table
- [x] Recalculate checksums
- [x] Handle composite glyphs (glyphs referencing other glyphs)

#### 2.4 CID Font Embedding
- [x] `PDF::Fonts::TrueTypeFont` — TrueType font handler
- [x] CIDFont Type 2 dictionary
- [x] Type 0 (composite) font dictionary
- [x] Font descriptor dictionary
  - [x] /FontBBox
  - [x] /ItalicAngle
  - [x] /Ascent, /Descent
  - [x] /CapHeight, /XHeight (if available)
  - [x] /StemV (estimate if not available)
  - [x] /Flags (serif, script, etc.)
- [x] Font file embedding
  - [x] /FontFile2 for TrueType
  - [x] Subset prefix (ABCDEF+FontName)
- [x] /CIDToGIDMap — CID to glyph ID mapping (Identity)
- [x] /W array — Glyph widths

#### 2.5 Unicode Support
- [x] `PDF::Fonts::TrueTypeFont#to_unicode_cmap` — CMap generation
- [x] /ToUnicode CMap stream
  - [x] `beginbfchar` / `endbfchar` mappings
- [x] Text encoding to CID conversion
- [x] Identity-H encoding

#### 2.6 Font Caching
- [x] Cache parsed fonts in document
- [x] Reuse font resources across pages
- [x] Deduplicate identical fonts

#### 2.7 Testing
- [x] Test subsetting reduces file size
- [x] Test Unicode text renders correctly
- [x] Test various TTF files (DejaVu Sans)
- [x] Test font metrics match expected widths

### Phase 3: Images ✅ COMPLETE

**Duration:** 2 weeks  
**Goal:** Embed JPEG and PNG images with transparency

#### 3.1 JPEG Support
- [x] `PDF::Images::JPEG` — JPEG handler
- [x] Read JPEG dimensions from header (SOF marker)
- [x] Detect color space (grayscale, RGB, CMYK)
- [x] Pass through raw DCT data (no re-encoding)
- [x] Create Image XObject dictionary
  - [x] /Type /XObject
  - [x] /Subtype /Image
  - [x] /Width, /Height
  - [x] /ColorSpace (/DeviceRGB, /DeviceGray, /DeviceCMYK)
  - [x] /BitsPerComponent 8
  - [x] /Filter /DCTDecode

#### 3.2 PNG Support
- [x] `PDF::Images::PNG` — PNG handler
- [x] Decode PNG using stumpy_png
- [x] Extract raw RGB/RGBA pixels
- [x] Re-encode with FlateDecode
- [x] Handle color types:
  - [x] Grayscale
  - [x] Grayscale + Alpha
  - [x] RGB
  - [x] RGBA
  - [ ] Indexed (palette) - decoded by stumpy_png
- [x] Alpha channel handling:
  - [x] Extract alpha as separate image
  - [x] Create soft mask (/SMask)
  - [x] Soft mask XObject dictionary

#### 3.3 Image XObject
- [x] `PDF::Images::Base` — Image XObject base class
- [x] Register in page resources
- [x] Image placement operator (`Do`)
- [x] Transformation matrix for positioning/scaling

#### 3.4 Image API
- [x] `PDF::Images::Image.load(path)` — Load image from file
- [x] `PDF::Images::Image.load(io)` — Load from IO
- [x] `PDF::Images::Image.load(bytes)` — Load from bytes
- [x] Auto-detect format (JPEG vs PNG)
- [x] `page.image(img, at:, width:, height:, scale:)`

#### 3.5 Testing
- [x] Test JPEG embedding (various sizes, color spaces)
- [x] Test PNG embedding (RGB, RGBA)
- [x] Test transparency renders correctly
- [x] Test image scaling maintains quality

### Phase 4: Graphics & Color

**Duration:** 2 weeks  
**Goal:** Full vector graphics capabilities

#### 4.1 Path Operations
- [ ] `PDF::Content::Path` — Path construction
- [ ] Path operators:
  - [ ] `m` — Move to
  - [ ] `l` — Line to
  - [ ] `c` — Cubic Bezier curve (two control points)
  - [ ] `v` — Cubic Bezier (first control = current point)
  - [ ] `y` — Cubic Bezier (second control = end point)
  - [ ] `h` — Close path
  - [ ] `re` — Rectangle
- [ ] Path painting operators:
  - [ ] `S` — Stroke
  - [ ] `s` — Close and stroke
  - [ ] `f` — Fill (non-zero winding)
  - [ ] `f*` — Fill (even-odd)
  - [ ] `B` — Fill and stroke
  - [ ] `B*` — Fill (even-odd) and stroke
  - [ ] `b` — Close, fill, stroke
  - [ ] `b*` — Close, fill (even-odd), stroke
  - [ ] `n` — End path (no paint)
- [ ] Clipping:
  - [ ] `W` — Clip (non-zero winding)
  - [ ] `W*` — Clip (even-odd)

#### 4.2 Graphics State
- [ ] `PDF::Content::Graphics` — Graphics state management
- [ ] State operators:
  - [ ] `q` — Save graphics state
  - [ ] `Q` — Restore graphics state
  - [ ] `cm` — Concatenate transformation matrix
  - [ ] `w` — Line width
  - [ ] `J` — Line cap style
  - [ ] `j` — Line join style
  - [ ] `M` — Miter limit
  - [ ] `d` — Dash pattern
  - [ ] `ri` — Rendering intent
  - [ ] `i` — Flatness tolerance
  - [ ] `gs` — Set graphics state from ExtGState
- [ ] Transformation helpers:
  - [ ] `translate(x, y)`
  - [ ] `rotate(degrees)`
  - [ ] `scale(sx, sy)`
  - [ ] `skew(ax, ay)`
  - [ ] `transform(a, b, c, d, e, f)`

#### 4.3 Color Operations
- [ ] `PDF::Content::Color` — Color management
- [ ] Device color spaces:
  - [ ] DeviceGray: `g` (fill), `G` (stroke)
  - [ ] DeviceRGB: `rg` (fill), `RG` (stroke)
  - [ ] DeviceCMYK: `k` (fill), `K` (stroke)
- [ ] Color space operators:
  - [ ] `cs` — Set fill color space
  - [ ] `CS` — Set stroke color space
  - [ ] `sc` / `scn` — Set fill color
  - [ ] `SC` / `SCN` — Set stroke color
- [ ] Named colors (convenience):
  - [ ] `:black`, `:white`, `:red`, `:green`, `:blue`, etc.
  - [ ] Hex color strings (`"#FF0000"`)

#### 4.4 Extended Graphics State
- [ ] `PDF::Object::ExtGState` — Extended graphics state dictionary
- [ ] Transparency:
  - [ ] `/CA` — Stroke opacity
  - [ ] `/ca` — Fill opacity
  - [ ] `/BM` — Blend mode
  - [ ] `/SMask` — Soft mask
- [ ] Other parameters:
  - [ ] `/LW` — Line width
  - [ ] `/LC` — Line cap
  - [ ] `/LJ` — Line join
  - [ ] `/ML` — Miter limit
  - [ ] `/D` — Dash pattern
- [ ] Register ExtGState in resources

#### 4.5 Shape Helpers
- [ ] `page.rectangle(x, y, w, h)`
- [ ] `page.circle(cx, cy, r)` — Approximated with Bezier curves
- [ ] `page.ellipse(cx, cy, rx, ry)`
- [ ] `page.polygon(points)`
- [ ] `page.rounded_rectangle(x, y, w, h, radius)`
- [ ] `page.arc(cx, cy, r, start_angle, end_angle)`

#### 4.6 Testing
- [ ] Test all path operators
- [ ] Test transformations
- [ ] Test transparency
- [ ] Test color spaces
- [ ] Visual verification of rendered output

### Phase 5: Parser Core

**Duration:** 3-4 weeks  
**Goal:** Load and parse existing PDF files

#### 5.1 Lexer
- [ ] `PDF::Parser::Lexer` — PDF tokenizer
- [ ] Token types:
  - [ ] Boolean (`true`, `false`)
  - [ ] Number (integer, real)
  - [ ] String (literal, hex)
  - [ ] Name
  - [ ] Array delimiters (`[`, `]`)
  - [ ] Dictionary delimiters (`<<`, `>>`)
  - [ ] Object keywords (`obj`, `endobj`, `stream`, `endstream`)
  - [ ] Reference marker (`R`)
  - [ ] `null`
- [ ] Handle comments (`%`)
- [ ] Handle whitespace and line endings
- [ ] Position tracking for error reporting

#### 5.2 Cross-Reference Parser
- [ ] `PDF::Parser::XRef` — XRef table/stream parser
- [ ] Find `startxref` and trailer
- [ ] Parse xref table format:
  ```
  xref
  0 10
  0000000000 65535 f 
  0000000015 00000 n 
  ...
  ```
- [ ] Parse xref stream format (PDF 1.5+):
  - [ ] Decode stream
  - [ ] Parse /W array (field widths)
  - [ ] Extract object offsets
- [ ] Handle hybrid-reference PDFs
- [ ] Build object offset map

#### 5.3 Object Loader
- [ ] `PDF::Parser::ObjectLoader` — Lazy object loading
- [ ] Seek to object offset
- [ ] Parse object header (`N M obj`)
- [ ] Parse object value
- [ ] Handle object streams (PDF 1.5+):
  - [ ] Decompress object stream
  - [ ] Parse inner object offsets
  - [ ] Extract individual objects
- [ ] Object caching
  - [ ] LRU cache for large documents
  - [ ] Strong references for frequently accessed objects

#### 5.4 Stream Decoding
- [ ] `PDF::Parser::StreamReader` — Stream content extraction
- [ ] Filter pipeline:
  - [ ] FlateDecode (zlib)
  - [ ] ASCIIHexDecode
  - [ ] ASCII85Decode
  - [ ] LZWDecode
  - [ ] RunLengthDecode
  - [ ] DCTDecode (leave encoded for images)
- [ ] Handle filter arrays (multiple filters)
- [ ] Handle decode parameters

#### 5.5 Document Reader
- [ ] `PDF::Parser::Reader` — High-level document reader
- [ ] `PDF::Parser.read(path)` — Read from file
- [ ] `PDF::Parser.read(io)` — Read from IO
- [ ] Load trailer and catalog
- [ ] Build page tree
- [ ] Extract metadata (/Info dictionary)
- [ ] Version detection

#### 5.6 Error Recovery
- [ ] `PDF::Parser::Recovery` — Malformed PDF handling
- [ ] Missing/wrong EOF:
  - [ ] Scan backwards for `%%EOF`
  - [ ] Try common offsets
- [ ] Corrupted xref:
  - [ ] Fallback to object scanning
  - [ ] Scan for `N M obj` patterns
  - [ ] Rebuild xref from found objects
- [ ] Broken stream lengths:
  - [ ] Scan for `endstream`
  - [ ] Try common stream terminators
- [ ] Missing required keys:
  - [ ] Use sensible defaults
  - [ ] Log warnings

#### 5.7 Testing
- [ ] Test with valid PDFs
- [ ] Test with malformed PDFs
- [ ] Test large PDFs (lazy loading)
- [ ] Test encrypted PDFs (fail gracefully for now)
- [ ] Corpus testing with real-world samples

### Phase 6: Text Extraction

**Duration:** 2-3 weeks  
**Goal:** Extract text content from PDFs

#### 6.1 Content Stream Parser
- [ ] Parse content stream operators
- [ ] Track graphics state during parsing
- [ ] Extract text-related operators
- [ ] Handle inline images (skip)

#### 6.2 Text State Tracking
- [ ] Current font and size
- [ ] Text matrix (Tm)
- [ ] Text line matrix
- [ ] Character and word spacing
- [ ] Horizontal scaling
- [ ] Text rise

#### 6.3 Font Encoding Resolution
- [ ] Identify font encoding:
  - [ ] WinAnsiEncoding
  - [ ] MacRomanEncoding
  - [ ] MacExpertEncoding
  - [ ] Standard encodings
- [ ] Parse /Encoding dictionary
- [ ] Apply /Differences array
- [ ] Handle /ToUnicode CMap

#### 6.4 ToUnicode CMap Parsing
- [ ] Parse CMap stream
- [ ] Extract `beginbfchar` mappings
- [ ] Extract `beginbfrange` ranges
- [ ] Build character code to Unicode map

#### 6.5 Text Extraction
- [ ] `page.extract_text` — Get page text
- [ ] Process text operators:
  - [ ] `Tj` — Show string
  - [ ] `TJ` — Show string array
  - [ ] `'` — Move and show
  - [ ] `"` — Set spacing and show
- [ ] Apply font encoding/ToUnicode
- [ ] Reconstruct words from glyphs
- [ ] Handle spacing and line breaks

#### 6.6 Reading Order (Basic)
- [ ] Sort text by position
- [ ] Detect line breaks by Y position
- [ ] Detect word breaks by X gaps
- [ ] Handle multi-column (future)

#### 6.7 Testing
- [ ] Test with various font encodings
- [ ] Test Unicode text extraction
- [ ] Test layout reconstruction
- [ ] Compare extracted text to source

### Phase 7: Advanced Features

**Duration:** Ongoing  
**Goal:** Forms, annotations, encryption, and more

#### 7.1 Annotations
- [ ] Link annotations
  - [ ] URI actions
  - [ ] GoTo actions (internal links)
- [ ] Text annotations (sticky notes)
- [ ] Highlight/underline/strikeout
- [ ] Widget annotations (form fields)
- [ ] Annotation appearance streams

#### 7.2 AcroForms
- [ ] Form field types:
  - [ ] Text fields
  - [ ] Checkboxes
  - [ ] Radio buttons
  - [ ] Dropdown/combo boxes
  - [ ] Push buttons
  - [ ] Signature fields (placeholder)
- [ ] Field hierarchy (/Parent, /Kids)
- [ ] Field appearance generation
- [ ] Form filling API:
  ```crystal
  doc = PDF::Parser.read("form.pdf")
  doc.fill_field("name", "John Doe")
  doc.fill_field("agree", true)
  doc.save("filled.pdf")
  ```

#### 7.3 Encryption (Reading)
- [ ] Detect encrypted PDFs
- [ ] Standard security handler
- [ ] Password verification
- [ ] RC4 decryption (40/128-bit)
- [ ] AES-128 decryption
- [ ] AES-256 decryption (PDF 2.0)
- [ ] Permission flags parsing

#### 7.4 Encryption (Writing)
- [ ] User and owner passwords
- [ ] Permission flags
- [ ] RC4 encryption
- [ ] AES encryption
- [ ] Encrypt all streams and strings

#### 7.5 Incremental Updates
- [ ] Append changes without rewriting
- [ ] New xref section at end
- [ ] /Prev pointer to previous xref
- [ ] Useful for:
  - [ ] Form filling
  - [ ] Adding annotations
  - [ ] Digital signatures

#### 7.6 Metadata
- [ ] Document information dictionary
  - [ ] /Title, /Author, /Subject, /Keywords
  - [ ] /Creator, /Producer
  - [ ] /CreationDate, /ModDate
- [ ] XMP metadata (PDF/A)

#### 7.7 Bookmarks/Outlines
- [ ] Document outline tree
- [ ] Bookmark destinations
- [ ] Outline item flags (bold, italic)

#### 7.8 High-Fidelity Text Extraction
- [ ] Reading order detection
- [ ] Column detection
- [ ] Table extraction
- [ ] Paragraph detection
- [ ] Preserve formatting structure

---

## Technical Specifications

### PDF Version Targeting

| Feature | Minimum Version | Notes |
|---------|-----------------|-------|
| Basic document | 1.0 | Header, body, xref, trailer |
| FlateDecode | 1.2 | zlib compression |
| TrueType fonts | 1.3 | Font embedding |
| Transparency | 1.4 | ExtGState with /ca, /CA |
| Object streams | 1.5 | Compressed object storage |
| XRef streams | 1.5 | Compressed cross-reference |
| AES-128 | 1.5 | Standard encryption |
| AES-256 | 1.7 ext 3 | PDF 2.0 encryption |

**Target:** Generate PDF 1.7 by default. Parse 1.0 through 2.0.

### Coordinate System

- Origin: Bottom-left corner of page
- Units: Points (1 point = 1/72 inch)
- Y-axis: Positive upward
- Standard page sizes:
  - Letter: 612 x 792 points (8.5 x 11 inches)
  - A4: 595.28 x 841.89 points (210 x 297 mm)
  - Legal: 612 x 1008 points (8.5 x 14 inches)

### Text Encoding

| Context | Encoding | Notes |
|---------|----------|-------|
| Literal strings | PDFDocEncoding | ISO Latin-1 superset |
| Unicode strings | UTF-16BE with BOM | For /Title, /Author, etc. |
| Content streams | Font-dependent | WinAnsi, Identity-H, etc. |
| Names | UTF-8 (PDF 1.7+) | Escaped as #XX |

### Standard 14 Type1 Fonts

| Font Name | Encoding |
|-----------|----------|
| Helvetica | WinAnsiEncoding |
| Helvetica-Bold | WinAnsiEncoding |
| Helvetica-Oblique | WinAnsiEncoding |
| Helvetica-BoldOblique | WinAnsiEncoding |
| Times-Roman | WinAnsiEncoding |
| Times-Bold | WinAnsiEncoding |
| Times-Italic | WinAnsiEncoding |
| Times-BoldItalic | WinAnsiEncoding |
| Courier | WinAnsiEncoding |
| Courier-Bold | WinAnsiEncoding |
| Courier-Oblique | WinAnsiEncoding |
| Courier-BoldOblique | WinAnsiEncoding |
| Symbol | SymbolEncoding |
| ZapfDingbats | ZapfDingbatsEncoding |

### TrueType Embedding Requirements

**Required Tables:**
- `cmap` — Character to glyph mapping
- `glyf` — Glyph outlines
- `head` — Font header
- `hhea` — Horizontal header
- `hmtx` — Horizontal metrics
- `loca` — Glyph locations
- `maxp` — Maximum profile
- `name` — Naming table
- `post` — PostScript info

**Optional Tables:**
- `OS/2` — Better metrics
- `cvt ` — Control values
- `fpgm` — Font program
- `prep` — CVT program
- `gasp` — Grid-fitting/anti-aliasing

### Image Format Requirements

**JPEG:**
- Baseline DCT only (no progressive)
- RGB or CMYK or Grayscale
- 8-bit per component

**PNG:**
- All color types supported
- Alpha channel → soft mask
- Interlaced images supported

### Compression

- All content streams: FlateDecode
- JPEG images: DCTDecode (passthrough)
- Font subsets: FlateDecode
- Object streams (future): FlateDecode

---

## Edge Cases & Error Handling

### Parsing Edge Cases

| Issue | Detection | Recovery |
|-------|-----------|----------|
| Missing EOF | File doesn't end with `%%EOF` | Scan backwards for marker |
| Wrong startxref | Offset points to wrong location | Scan for `xref` keyword |
| Corrupted xref | Invalid entry format | Rebuild by scanning objects |
| Object streams | Objects stored in compressed stream | Decompress and parse inner objects |
| Hybrid reference | Both xref table and stream | Parse both, merge |
| Wrong object offsets | Object not at stated position | Scan for `N M obj` pattern |
| Broken stream length | /Length is wrong | Scan for `endstream` |
| Invalid stream filters | Unknown filter name | Skip stream, log warning |
| Circular references | Objects reference each other | Track visited objects |
| Missing required keys | Dict missing mandatory key | Use default value |

### Font Edge Cases

| Issue | Detection | Handling |
|-------|-----------|----------|
| Missing ToUnicode | No /ToUnicode entry | Guess from encoding |
| Unknown encoding | /Encoding not standard | Fall back to WinAnsi |
| Composite glyphs | Glyph references other glyphs | Include referenced glyphs in subset |
| CFF fonts | Font has `CFF ` table instead of `glyf` | Parse CFF table (future) |
| Variable fonts | Font has `fvar` table | Use default instance |
| Missing metrics | No width info for glyph | Estimate from other glyphs |

### Text Extraction Edge Cases

| Issue | Detection | Handling |
|-------|-----------|----------|
| Text as paths | No text operators, only path ops | Cannot extract |
| Invisible text | Rendering mode = 3 | Include (for OCR layers) |
| Overlapping text | Same position, different text | Keep both |
| RTL text | Hebrew/Arabic characters | Detect and reverse |
| Vertical text | /WMode = 1 | Handle vertical metrics |
| ActualText | /ActualText in structure | Use ActualText value |
| ToUnicode failure | CMap doesn't map character | Use replacement character |

### Error Handling Strategy

```crystal
# Parsing errors
begin
  doc = PDF::Parser.read("file.pdf")
rescue PDF::ParseError => e
  # Syntax error, unrecoverable
  puts "Parse error: #{e.message}"
rescue PDF::UnsupportedFeatureError => e
  # Feature not implemented
  puts "Unsupported: #{e.message}"
rescue PDF::EncryptedError => e
  # Need password
  puts "Encrypted: #{e.message}"
end

# Recoverable issues logged as warnings
doc = PDF::Parser.read("file.pdf")
doc.warnings.each do |warning|
  puts "Warning: #{warning}"
end
```

---

## Testing Strategy

### Unit Tests

- Each class has corresponding spec file
- Test object serialization round-trips
- Test edge cases for each type

### Integration Tests

- Generate PDFs and verify structure
- Parse generated PDFs back
- Compare to known-good reference files

### Golden Tests

- Byte-for-byte comparison to reference output
- Useful for detecting accidental changes
- Update goldens explicitly when format changes

### Corpus Tests

- Collect diverse real-world PDFs
- Test parsing succeeds
- Test text extraction accuracy
- Categories:
  - Simple (basic text)
  - Complex (fonts, images, graphics)
  - Malformed (common issues)
  - Large (100+ pages)

### Fuzzing

- Feed random/mutated input to parser
- Catch crashes and hangs
- Use AFL or similar

### Visual Verification

- Render generated PDFs
- Compare to expected output
- Use PDF.js or similar for headless rendering

### Performance Tests

- Measure generation speed
- Measure parsing speed
- Measure memory usage
- Test with large documents

---

## References

### PDF Specification

- [PDF 1.7 Reference (ISO 32000-1:2008)](https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf)
- [PDF 2.0 Reference (ISO 32000-2:2020)](https://www.pdfa.org/sponsored-standards/)

### TrueType/OpenType

- [OpenType Specification](https://docs.microsoft.com/en-us/typography/opentype/spec/)
- [TrueType Reference Manual](https://developer.apple.com/fonts/TrueType-Reference-Manual/)

### Related Projects

- [PDF.js](https://github.com/niccolodev/pdf.js) — JavaScript PDF reader
- [HexaPDF](https://hexapdf.gettalong.org/) — Ruby PDF library (design reference)
- [pdf-lib](https://github.com/Hopding/pdf-lib) — JavaScript PDF creation
- [PyPDF2](https://github.com/py-pdf/pypdf) — Python PDF library
- [libharu](https://github.com/libharu/libharu) — C PDF library

### Crystal Resources

- [Crystal Language](https://crystal-lang.org/)
- [stumpy_png](https://github.com/stumpycr/stumpy_png)
- [stumpy_jpeg](https://github.com/stumpycr/stumpy_jpeg)

---

## Changelog

### v0.1.0 (Planned)
- Initial release
- PDF generation with Type1 fonts
- Basic text and graphics

### v0.2.0 (Planned)
- TrueType font embedding ✅
- Font subsetting ✅
- Unicode support ✅

### v0.3.0 (Planned)
- Image embedding (JPEG, PNG) ✅
- Transparency support ✅

### v0.4.0 (Planned)
- PDF parsing
- Text extraction

---

*Document last updated: January 2026*
