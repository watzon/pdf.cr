require "spec"
require "../src/pdf"

# Test helpers
module TestHelpers
  # Helper to check PDF output format
  def self.valid_pdf_header?(bytes : Bytes) : Bool
    header = String.new(bytes[0, 8])
    header.starts_with?("%PDF-")
  end

  # Helper to check PDF trailer
  def self.valid_pdf_trailer?(bytes : Bytes) : Bool
    trailer = String.new(bytes[-6, 6])
    trailer.includes?("%%EOF")
  end
end
