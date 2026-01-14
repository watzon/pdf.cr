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
  end

  describe "#font_file_stream" do
    it "returns compressed font data stream" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("Test")

      stream = font.font_file_stream

      stream.should be_a(PDF::Objects::Stream)
      stream[PDF::Objects::Name.new("Length1")].should be_a(PDF::Objects::Number)
    end
  end

  describe "#to_unicode_cmap" do
    it "returns ToUnicode CMap stream" do
      font = PDF::Fonts::TrueTypeFont.load(TRUETYPE_FONT_SPEC_PATH)
      font.use("ABC")

      stream = font.to_unicode_cmap

      stream.should be_a(PDF::Objects::Stream)
    end
  end
end
