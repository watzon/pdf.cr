require "./spec_helper"

describe PDF do
  it "has a version number" do
    PDF::VERSION.should eq("0.1.0")
  end

  it "has a PDF version" do
    PDF::PDF_VERSION.should eq("1.7")
  end
end

# Require all spec files
require "./pdf/objects/*"
require "./pdf/filters/*"
require "./pdf/fonts/*"
require "./pdf/fonts/truetype/*"
require "./pdf/document_spec"
require "./pdf/page_spec"
require "./integration/*"
