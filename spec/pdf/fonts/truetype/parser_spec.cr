require "../../../spec_helper"

TRUETYPE_PARSER_SPEC_FONT_PATH = "spec/fixtures/fonts/DejaVuSans.ttf"

describe PDF::Fonts::TrueType::Parser do
  describe ".parse" do
    it "parses a valid TrueType font file" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      parser.should be_a(PDF::Fonts::TrueType::Parser)
    end

    it "parses from bytes" do
      data = File.read(TRUETYPE_PARSER_SPEC_FONT_PATH).to_slice
      parser = PDF::Fonts::TrueType::Parser.parse(data)
      parser.should be_a(PDF::Fonts::TrueType::Parser)
    end

    it "raises for invalid font data" do
      expect_raises(PDF::Fonts::TrueType::ParseError) do
        PDF::Fonts::TrueType::Parser.parse("invalid data".to_slice)
      end
    end

    it "raises for data too small" do
      expect_raises(PDF::Fonts::TrueType::ParseError, /too small/) do
        PDF::Fonts::TrueType::Parser.parse(Bytes.new(5))
      end
    end
  end

  describe "#truetype?" do
    it "returns true for TrueType font" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      parser.truetype?.should be_true
    end
  end

  describe "#has_table?" do
    it "returns true for existing tables" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      parser.has_table?("head").should be_true
      parser.has_table?("hhea").should be_true
      parser.has_table?("maxp").should be_true
      parser.has_table?("cmap").should be_true
    end

    it "returns false for non-existing tables" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      parser.has_table?("FAKE").should be_false
    end
  end

  describe "#head" do
    it "parses head table" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      head = parser.head

      head.units_per_em.should be > 0
      head.magic_number.should eq(0x5F0F3CF5_u32)
    end

    it "returns units per em" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      parser.units_per_em.should eq(parser.head.units_per_em)
    end
  end

  describe "#hhea" do
    it "parses hhea table" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      hhea = parser.hhea

      hhea.ascent.should be > 0
      hhea.descent.should be < 0
      hhea.number_of_h_metrics.should be > 0
    end
  end

  describe "#maxp" do
    it "parses maxp table" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      maxp = parser.maxp

      maxp.num_glyphs.should be > 0
    end
  end

  describe "#cmap" do
    it "parses cmap table" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      cmap = parser.cmap

      cmap.encoding_records.should_not be_empty
    end

    it "provides Unicode mapping" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      mapping = parser.cmap.unicode_mapping

      mapping.should_not be_empty
    end
  end

  describe "#glyph_id" do
    it "returns glyph ID for ASCII characters" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)

      # 'A' should have a glyph
      glyph_a = parser.glyph_id('A')
      glyph_a.should be > 0

      # Space should have a glyph
      glyph_space = parser.glyph_id(' ')
      glyph_space.should be > 0
    end

    it "returns 0 for unmapped characters" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)

      # Use a very high codepoint that's unlikely to be mapped
      glyph = parser.glyph_id(0x10FFFF_u32)
      glyph.should eq(0)
    end
  end

  describe "#advance_width" do
    it "returns width for glyphs" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)

      glyph_a = parser.glyph_id('A')
      width = parser.advance_width(glyph_a)
      width.should be > 0
    end
  end

  describe "#char_width" do
    it "returns width for characters" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)

      width_a = parser.char_width('A')
      width_a.should be > 0

      width_i = parser.char_width('i')
      width_i.should be > 0

      # 'A' should be wider than 'i' in most fonts
      width_a.should be > width_i
    end
  end

  describe "#name" do
    it "parses name table" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)
      name = parser.name

      name.records.should_not be_empty
    end

    it "returns PostScript name" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)

      ps_name = parser.postscript_name
      ps_name.should_not be_empty
      ps_name.should contain("DejaVu")
    end

    it "returns family name" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)

      family = parser.family_name
      family.should_not be_empty
    end
  end

  describe "#ascender and #descender" do
    it "returns font metrics" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)

      parser.ascender.should be > 0
      parser.descender.should be < 0
    end
  end

  describe "#bounding_box" do
    it "returns font bounding box" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)

      bbox = parser.bounding_box
      # x_min, y_min, x_max, y_max
      bbox[2].should be > bbox[0] # x_max > x_min
      bbox[3].should be > bbox[1] # y_max > y_min
    end
  end

  describe "#flags" do
    it "returns PDF font descriptor flags" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_PARSER_SPEC_FONT_PATH)

      flags = parser.flags
      flags.should be > 0
    end
  end
end
