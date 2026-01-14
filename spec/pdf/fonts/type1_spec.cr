require "../../spec_helper"

describe PDF::Fonts::Type1 do
  describe "initialization" do
    it "creates font with valid name" do
      font = PDF::Fonts::Type1.new("Helvetica")
      font.name.should eq("Helvetica")
    end

    it "raises for invalid font name" do
      expect_raises(ArgumentError, /Unknown Type1 font/) do
        PDF::Fonts::Type1.new("InvalidFont")
      end
    end

    it "accepts all standard fonts" do
      PDF::Fonts::Type1::STANDARD_FONTS.each do |name|
        font = PDF::Fonts::Type1.new(name)
        font.name.should eq(name)
      end
    end
  end

  describe "#to_dictionary" do
    it "creates proper font dictionary for Helvetica" do
      font = PDF::Fonts::Type1.new("Helvetica")
      dict = font.to_dictionary

      dict["Type"].should eq(PDF::Objects::Name::FONT)
      dict["Subtype"].should eq(PDF::Objects::Name.new("Type1"))
      dict["BaseFont"].should eq(PDF::Objects::Name.new("Helvetica"))
      dict["Encoding"].should eq(PDF::Objects::Name.new("WinAnsiEncoding"))
    end

    it "omits encoding for Symbol font" do
      font = PDF::Fonts::Type1.new("Symbol")
      dict = font.to_dictionary

      dict["BaseFont"].should eq(PDF::Objects::Name.new("Symbol"))
      dict["Encoding"]?.should be_nil
    end

    it "omits encoding for ZapfDingbats font" do
      font = PDF::Fonts::Type1.new("ZapfDingbats")
      dict = font.to_dictionary

      dict["Encoding"]?.should be_nil
    end
  end

  describe "#glyph_width" do
    it "returns correct width for Helvetica 'A'" do
      font = PDF::Fonts::Type1.new("Helvetica")
      font.glyph_width('A').should eq(667)
    end

    it "returns correct width for Helvetica space" do
      font = PDF::Fonts::Type1.new("Helvetica")
      font.glyph_width(' ').should eq(278)
    end

    it "returns correct width for Courier (monospaced)" do
      font = PDF::Fonts::Type1.new("Courier")
      font.glyph_width('A').should eq(600)
      font.glyph_width('i').should eq(600)
      font.glyph_width('W').should eq(600)
    end

    it "returns default width for unknown characters" do
      font = PDF::Fonts::Type1.new("Helvetica")
      # Character outside defined range
      font.glyph_width('\u0000').should eq(PDF::Fonts::Type1::DEFAULT_WIDTH)
    end
  end

  describe "#string_width" do
    it "calculates width of string at given size" do
      font = PDF::Fonts::Type1.new("Helvetica")
      # "A" = 667 units, at 12pt: 667 * 12 / 1000 = 8.004
      width = font.string_width("A", 12.0)
      width.should be_close(8.004, 0.001)
    end

    it "calculates width of multi-character string" do
      font = PDF::Fonts::Type1.new("Helvetica")
      # "AB" = 667 + 667 = 1334 units, at 10pt: 13.34
      width = font.string_width("AB", 10.0)
      width.should be_close(13.34, 0.01)
    end
  end
end
