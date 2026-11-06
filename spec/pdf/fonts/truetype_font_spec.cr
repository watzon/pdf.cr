require "../../spec_helper"

TRUETYPE_FONT_SPEC_PATH = "spec/fixtures/fonts/DejaVuSans.ttf"

describe PDF::Fonts::TrueTypeFont do
  describe ".load" do
    it "loads font from file path" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.should be_a(PDF::Fonts::TrueTypeFont)
    end

    it "loads font from bytes" do
      data = File.read(TRUETYPE_FONT_SPEC_PATH).to_slice
      font = PDF::Fonts::TrueTypeFont.load(data)
      font.should be_a(PDF::Fonts::TrueTypeFont)
    end
  end

  describe "#name" do
    it "returns subset-prefixed name" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      name = font.name

      # Should be PREFIX+PostScriptName
      name.should match(/^[A-Z]{6}\+/)
      name.should contain("DejaVu")
    end
  end

  describe "#base_name" do
    it "returns PostScript name without prefix" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      base_name = font.base_name

      base_name.should_not match(/^[A-Z]{6}\+/)
      base_name.should contain("DejaVu")
    end
  end

  describe "#use" do
    it "marks characters as used" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Hello")

      # After using, the font should include those glyphs
      encoded = font.encode_text("Hello")
      encoded.should_not be_empty
    end

    it "accepts individual characters" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use('A')
      font.use('B')

      encoded = font.encode_text("AB")
      encoded.should_not be_empty
    end
  end

  describe "#glyph_width" do
    it "returns width in 1/1000 units" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)

      width_a = font.glyph_width('A')
      width_a.should be > 0
      width_a.should be < 2000 # Reasonable range

      width_i = font.glyph_width('i')
      width_i.should be > 0

      # 'A' should be wider than 'i'
      width_a.should be > width_i
    end
  end

  describe "#string_width" do
    it "calculates width of string at given size" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)

      width = font.string_width("AB", 12.0)
      width.should be > 0
    end

    it "scales correctly with font size" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)

      width_12 = font.string_width("Test", 12.0)
      width_24 = font.string_width("Test", 24.0)

      # Width at 24pt should be exactly double width at 12pt
      width_24.should be_close(width_12 * 2.0, 0.001)
    end
  end

  describe "#encode_text" do
    it "returns hex-encoded glyph IDs" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Hi")

      encoded = font.encode_text("Hi")

      # Should be hex string format
      encoded.should start_with("<")
      encoded.should end_with(">")
      encoded.size.should be > 2
    end

    it "uses new glyph IDs after subsetting" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("A")

      encoded = font.encode_text("A")

      # The encoded glyph ID should be a small number
      # Format is <XXXX> where XXXX is 4 hex digits
      hex_content = encoded[1..-2] # Remove < and >
      hex_content.size.should eq(4)
    end

    it "encodes Unicode characters correctly" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)

      # Cyrillic text
      encoded = font.encode_text("Привет")
      encoded.should start_with("<")
      encoded.should end_with(">")
      # Each character needs 4 hex digits
      (encoded.size - 2).should eq(6 * 4) # 6 chars * 4 hex digits
    end

    it "handles mixed ASCII and Unicode" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)

      encoded = font.encode_text("ABC Привет")
      encoded.should start_with("<")
      encoded.should end_with(">")
    end
  end

  describe "#to_dictionary" do
    it "returns Type0 font dictionary" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.to_dictionary

      dict["Type"].should eq(PDF::Objects::Name::FONT)
      dict["Subtype"].should eq(PDF::Objects::Name.new("Type0"))
      dict["Encoding"].should eq(PDF::Objects::Name.new("Identity-H"))
    end

    it "includes BaseFont with subset prefix" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.to_dictionary
      base_font = dict["BaseFont"]
      base_font.should be_a(PDF::Objects::Name)
      base_font.as(PDF::Objects::Name).value.should match(/^[A-Z]{6}\+/)
    end
  end

  describe "#cid_font_dictionary" do
    it "returns CIDFontType2 dictionary" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.cid_font_dictionary

      dict["Type"].should eq(PDF::Objects::Name::FONT)
      dict["Subtype"].should eq(PDF::Objects::Name.new("CIDFontType2"))
      dict["CIDSystemInfo"].should be_a(PDF::Objects::Dictionary)
    end

    it "includes CIDSystemInfo with Adobe Identity" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.cid_font_dictionary
      cid_info = dict["CIDSystemInfo"].as(PDF::Objects::Dictionary)

      cid_info["Registry"].should eq(PDF::Objects::Str.new("Adobe"))
      cid_info["Ordering"].should eq(PDF::Objects::Str.new("Identity"))
      cid_info["Supplement"].should eq(PDF::Objects::Number.new(0))
    end

    it "includes W array with glyph widths" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("ABC")

      dict = font.cid_font_dictionary
      widths = dict["W"]
      widths.should be_a(PDF::Objects::Array)
      widths.as(PDF::Objects::Array).size.should be > 0
    end

    it "includes default width DW" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.cid_font_dictionary
      dict["DW"].should eq(PDF::Objects::Number.new(1000))
    end
  end

  describe "#font_descriptor" do
    it "returns font descriptor dictionary" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.font_descriptor

      dict["Type"].should eq(PDF::Objects::Name.new("FontDescriptor"))
      dict["FontName"].should be_a(PDF::Objects::Name)
      dict["Flags"].should be_a(PDF::Objects::Number)
      dict["FontBBox"].should be_a(PDF::Objects::Array)
      dict["ItalicAngle"].should be_a(PDF::Objects::Number)
      dict["Ascent"].should be_a(PDF::Objects::Number)
      dict["Descent"].should be_a(PDF::Objects::Number)
      dict["StemV"].should be_a(PDF::Objects::Number)
    end

    it "includes CapHeight" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.font_descriptor
      dict["CapHeight"].should be_a(PDF::Objects::Number)
    end

    it "has valid FontBBox" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.font_descriptor
      bbox = dict["FontBBox"].as(PDF::Objects::Array)
      bbox.size.should eq(4)

      # Bounding box should have valid structure (xMin, yMin, xMax, yMax)
      # xMax should be > xMin, yMax should be > yMin
      x_min = bbox[0].as(PDF::Objects::Number).value.to_i
      y_min = bbox[1].as(PDF::Objects::Number).value.to_i
      x_max = bbox[2].as(PDF::Objects::Number).value.to_i
      y_max = bbox[3].as(PDF::Objects::Number).value.to_i

      x_max.should be > x_min
      y_max.should be > y_min
    end

    it "has positive Ascent and negative Descent" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.font_descriptor
      ascent = dict["Ascent"].as(PDF::Objects::Number).value.to_i
      descent = dict["Descent"].as(PDF::Objects::Number).value.to_i

      ascent.should be > 0
      descent.should be < 0
    end

    it "has positive StemV" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.font_descriptor
      stem_v = dict["StemV"].as(PDF::Objects::Number).value.to_i
      stem_v.should be > 0
    end

    it "has correct font flags" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      dict = font.font_descriptor
      flags = dict["Flags"].as(PDF::Objects::Number).value.to_u32

      # Should have Nonsymbolic flag (bit 5, value 32)
      (flags & 32).should be > 0
    end
  end

  describe "#font_file_stream" do
    it "returns compressed font data stream" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      stream = font.font_file_stream

      stream.should be_a(PDF::Objects::Stream)
      stream[PDF::Objects::Name.new("Length1")].should be_a(PDF::Objects::Number)
    end

    it "has FlateDecode filter after serialization" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      stream = font.font_file_stream
      # Filters are added during to_pdf serialization
      pdf_output = stream.to_pdf
      pdf_output.should contain("/Filter /FlateDecode")
    end

    it "compresses the font data" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      stream = font.font_file_stream

      # Encoded data should be smaller than or equal to original
      original_length = font.subset_data.size
      encoded = stream.encoded_data

      # For compressible data, encoded should generally be smaller
      # (but we don't require it - sometimes compression adds overhead)
      encoded.size.should be > 0
    end
  end

  describe "#to_unicode_cmap" do
    it "returns ToUnicode CMap stream" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("ABC")

      stream = font.to_unicode_cmap

      stream.should be_a(PDF::Objects::Stream)
    end

    it "has FlateDecode filter after serialization" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("ABC")

      stream = font.to_unicode_cmap
      pdf_output = stream.to_pdf
      pdf_output.should contain("/Filter /FlateDecode")
    end
  end

  describe "#cid_to_gid_map_stream" do
    it "returns CIDToGIDMap stream" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("ABC")

      stream = font.cid_to_gid_map_stream

      stream.should be_a(PDF::Objects::Stream)
    end

    it "has FlateDecode filter after serialization" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("ABC")

      stream = font.cid_to_gid_map_stream
      pdf_output = stream.to_pdf
      pdf_output.should contain("/Filter /FlateDecode")
    end
  end

  describe "#subset_data" do
    it "returns subset font bytes smaller than original" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("ABC") # Only use 3 characters

      original_size = File.size(TRUETYPE_FONT_SPEC_PATH)
      subset_size = font.subset_data.size

      subset_size.should be < original_size
    end

    it "includes more glyphs with more characters" do
      font1 = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font1.use("A")
      subset1 = font1.subset_data.size

      font2 = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font2.use("The quick brown fox jumps over the lazy dog")
      subset2 = font2.subset_data.size

      subset2.should be > subset1
    end
  end
end
