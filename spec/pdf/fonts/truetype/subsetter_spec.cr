require "../../../spec_helper"

TRUETYPE_SUBSETTER_SPEC_FONT_PATH = "spec/fixtures/fonts/DejaVuSans.ttf"

describe PDF::Fonts::TrueType::Subsetter do

  describe "#subset" do
    it "creates a subset font with used characters" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_SUBSETTER_SPEC_FONT_PATH)
      subsetter = PDF::Fonts::TrueType::Subsetter.new(parser)

      subsetter.use("Hello")
      subset_data = subsetter.subset

      subset_data.should_not be_empty
      # Subset should be smaller than original
      subset_data.size.should be < parser.data.size
    end

    it "always includes .notdef glyph" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_SUBSETTER_SPEC_FONT_PATH)
      subsetter = PDF::Fonts::TrueType::Subsetter.new(parser)

      subsetter.use("A")
      subset_data = subsetter.subset

      # Parse the subset to verify structure
      subset_parser = PDF::Fonts::TrueType::Parser.parse(subset_data)
      subset_parser.maxp.num_glyphs.should be >= 2 # At least .notdef and 'A'
    end

    it "includes component glyphs for composite glyphs" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_SUBSETTER_SPEC_FONT_PATH)
      subsetter = PDF::Fonts::TrueType::Subsetter.new(parser)

      # Use a variety of characters
      subsetter.use("Hello World!")
      subset_data = subsetter.subset

      # Subset should be valid
      subset_parser = PDF::Fonts::TrueType::Parser.parse(subset_data)
      subset_parser.maxp.num_glyphs.should be > 0
    end
  end

  describe "#unicode_to_glyph_map" do
    it "returns mapping of used characters to new glyph IDs" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_SUBSETTER_SPEC_FONT_PATH)
      subsetter = PDF::Fonts::TrueType::Subsetter.new(parser)

      subsetter.use("ABC")
      subsetter.subset # Must call subset first

      mapping = subsetter.unicode_to_glyph_map

      # Should have mappings for A, B, C
      mapping.has_key?('A'.ord.to_u32).should be_true
      mapping.has_key?('B'.ord.to_u32).should be_true
      mapping.has_key?('C'.ord.to_u32).should be_true
    end

    it "uses sequential new glyph IDs" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_SUBSETTER_SPEC_FONT_PATH)
      subsetter = PDF::Fonts::TrueType::Subsetter.new(parser)

      subsetter.use("AB")
      subsetter.subset

      mapping = subsetter.unicode_to_glyph_map
      glyph_ids = mapping.values.sort

      # IDs should be low numbers (starting after .notdef at 0)
      glyph_ids.each do |id|
        id.should be < 10 # Should be small sequential IDs
      end
    end
  end

  describe "#new_glyph_id" do
    it "returns new glyph ID for old glyph ID" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_SUBSETTER_SPEC_FONT_PATH)
      subsetter = PDF::Fonts::TrueType::Subsetter.new(parser)

      subsetter.use("A")
      subsetter.subset

      old_glyph_id = parser.glyph_id('A')
      new_glyph_id = subsetter.new_glyph_id(old_glyph_id)

      new_glyph_id.should be > 0
      new_glyph_id.should be < old_glyph_id # New ID should be smaller
    end

    it "returns 0 for unmapped glyphs" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_SUBSETTER_SPEC_FONT_PATH)
      subsetter = PDF::Fonts::TrueType::Subsetter.new(parser)

      subsetter.use("A")
      subsetter.subset

      # Use a glyph ID for a character not in the subset
      unmapped_glyph_id = parser.glyph_id('Z')
      new_id = subsetter.new_glyph_id(unmapped_glyph_id)

      new_id.should eq(0)
    end
  end

  describe "subset font validity" do
    it "creates a valid TrueType font" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_SUBSETTER_SPEC_FONT_PATH)
      subsetter = PDF::Fonts::TrueType::Subsetter.new(parser)

      subsetter.use("The quick brown fox jumps over the lazy dog.")
      subset_data = subsetter.subset

      # Should be parseable
      subset_parser = PDF::Fonts::TrueType::Parser.parse(subset_data)

      # Should have required tables
      subset_parser.has_table?("head").should be_true
      subset_parser.has_table?("hhea").should be_true
      subset_parser.has_table?("maxp").should be_true
      subset_parser.has_table?("cmap").should be_true
      subset_parser.has_table?("loca").should be_true
      subset_parser.has_table?("glyf").should be_true
      subset_parser.has_table?("hmtx").should be_true
      subset_parser.has_table?("post").should be_true
      subset_parser.has_table?("name").should be_true
    end

    it "preserves font metrics" do
      parser = PDF::Fonts::TrueType::Parser.parse(TRUETYPE_SUBSETTER_SPEC_FONT_PATH)
      subsetter = PDF::Fonts::TrueType::Subsetter.new(parser)

      subsetter.use("A")
      subset_data = subsetter.subset
      subset_parser = PDF::Fonts::TrueType::Parser.parse(subset_data)

      # Units per em should be preserved
      subset_parser.units_per_em.should eq(parser.units_per_em)

      # Ascender/descender should be preserved
      subset_parser.ascender.should eq(parser.ascender)
      subset_parser.descender.should eq(parser.descender)
    end
  end
end
