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

# Filters (compression/encoding)
require "./pdf/filters/base"
require "./pdf/filters/flate"

# Font handling
require "./pdf/fonts/base"
require "./pdf/fonts/type1"

# Document writer
require "./pdf/writer/document_writer"

# Document structure
require "./pdf/document"
require "./pdf/page"
