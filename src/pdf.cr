# A pure Crystal library for PDF generation and parsing.
#
# ## Quick Start
#
# ```
# require "pdf"
#
# pdf = PDF::Document.new
#
# pdf.page do |page|
#   page.font "Helvetica", size: 12
#   page.text "Hello, Crystal!", at: {72, 720}
# end
#
# pdf.save("output.pdf")
# ```
module PDF
  VERSION = "0.1.0"

  # PDF version to generate (1.7 = ISO 32000-1:2008)
  PDF_VERSION = "1.7"
end

# Core object model (order matters - base first)
require "./pdf/objects/base"
require "./pdf/objects/null"
require "./pdf/objects/boolean"
require "./pdf/objects/number"
require "./pdf/objects/name"
require "./pdf/objects/string"
require "./pdf/objects/array"
require "./pdf/objects/dictionary"
require "./pdf/objects/reference"
require "./pdf/objects/stream"
require "./pdf/objects/indirect"
require "./pdf/objects/ext_g_state"

# Filters (compression/encoding)
require "./pdf/filters/base"
require "./pdf/filters/flate"
require "./pdf/filters/dct"

# Content stream operations
require "./pdf/content/color"
require "./pdf/content/graphics_state"

# Font handling
require "./pdf/fonts/base"
require "./pdf/fonts/type1"
require "./pdf/fonts/truetype"
require "./pdf/fonts/truetype_font"

# Image handling
require "./pdf/images/base"
require "./pdf/images/jpeg"
require "./pdf/images/png"
require "./pdf/images/image"

# Document writer
require "./pdf/writer/document_writer"

# Text layout engine
require "./pdf/text/formatted"

# Layout engine
require "./pdf/layout"

# Table engine
require "./pdf/table"

# SVG rendering engine
require "./pdf/svg"

# Document structure
require "./pdf/document"
require "./pdf/page"
require "./pdf/page_formatted_text"
require "./pdf/page_bounding_box"
require "./pdf/page_table"
require "./pdf/page_svg"
