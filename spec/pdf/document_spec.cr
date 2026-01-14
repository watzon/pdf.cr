require "../spec_helper"

describe PDF::Document do
  describe "initialization" do
    it "creates empty document" do
      doc = PDF::Document.new
      doc.pages.should be_empty
      doc.objects.should be_empty
    end

    it "has default producer" do
      doc = PDF::Document.new
      doc.producer.should eq("pdf.cr #{PDF::VERSION}")
    end
  end

  describe "#page" do
    it "creates a page with default size" do
      doc = PDF::Document.new
      doc.page { }
      doc.pages.size.should eq(1)
      doc.pages.first.width.should eq(612.0)
      doc.pages.first.height.should eq(792.0)
    end

    it "creates a page with custom size" do
      doc = PDF::Document.new
      doc.page(width: 400, height: 600) { }
      doc.pages.first.width.should eq(400.0)
      doc.pages.first.height.should eq(600.0)
    end

    it "creates a page with named size" do
      doc = PDF::Document.new
      doc.page(size: :a4) { }
      doc.pages.first.width.should eq(595.0)
      doc.pages.first.height.should eq(842.0)
    end

    it "creates a landscape page" do
      doc = PDF::Document.new
      doc.page(size: :letter, orientation: :landscape) { }
      doc.pages.first.width.should eq(792.0)
      doc.pages.first.height.should eq(612.0)
    end

    it "yields the page for content" do
      doc = PDF::Document.new
      page_received = nil
      doc.page { |p| page_received = p }
      page_received.should_not be_nil
      page_received.should be_a(PDF::Page)
    end
  end

  describe "#font" do
    it "returns Type1 font for standard fonts" do
      doc = PDF::Document.new
      font = doc.font("Helvetica")
      font.should be_a(PDF::Fonts::Type1)
    end

    it "caches font instances" do
      doc = PDF::Document.new
      font1 = doc.font("Helvetica")
      font2 = doc.font("Helvetica")
      font1.should be(font2)
    end

    it "raises for unknown fonts" do
      doc = PDF::Document.new
      expect_raises(ArgumentError, /Unknown font/) do
        doc.font("UnknownFont")
      end
    end
  end

  describe "#allocate_object_id" do
    it "returns sequential IDs starting from 1" do
      doc = PDF::Document.new
      doc.allocate_object_id.should eq(1)
      doc.allocate_object_id.should eq(2)
      doc.allocate_object_id.should eq(3)
    end
  end

  describe "#register_object" do
    it "creates and registers indirect object" do
      doc = PDF::Document.new
      dict = PDF::Objects::Dictionary.new
      obj = doc.register_object(dict)

      obj.should be_a(PDF::Objects::Indirect)
      obj.object_number.should eq(1)
      doc.objects.should contain(obj)
    end
  end

  describe "metadata" do
    it "supports setting title" do
      doc = PDF::Document.new
      doc.title = "Test Document"
      doc.title.should eq("Test Document")
    end

    it "supports setting author" do
      doc = PDF::Document.new
      doc.author = "Test Author"
      doc.author.should eq("Test Author")
    end
  end

  describe "#to_slice" do
    it "generates valid PDF bytes" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font "Helvetica", size: 12
        page.text "Hello", at: {72, 720}
      end

      bytes = doc.to_slice

      # Check PDF header
      header = String.new(bytes[0, 8])
      header.should start_with("%PDF-1.7")

      # Check for EOF marker
      trailer = String.new(bytes[-10, 10])
      trailer.should contain("%%EOF")
    end
  end
end
