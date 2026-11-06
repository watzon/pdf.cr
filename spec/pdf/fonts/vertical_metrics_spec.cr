require "../../spec_helper"

private DEJAVU = "#{__DIR__}/../../fixtures/fonts/DejaVuSans.ttf"

describe "font vertical metrics" do
  describe PDF::Fonts::Type1 do
    it "uses the AFM ascender, descender and line gap" do
      font = PDF::Fonts::Type1.new("Helvetica")
      {font.ascender, font.descender, font.line_gap}.should eq({718, -207, 231})
    end

    it "has different line gaps for variants with a different FontBBox" do
      PDF::Fonts::Type1.new("Times-Roman").line_gap.should eq(216)
      PDF::Fonts::Type1.new("Times-Bold").line_gap.should eq(253)
    end

    it "has metrics for each standard 14 font" do
      PDF::Fonts::Type1::STANDARD_FONTS.each do |name|
        font = PDF::Fonts::Type1.new(name)
        font.ascender.should be > 0
        font.descender.should be < 0
        font.line_gap.should be >= 0
      end
    end

    it "computes the line height from the metrics" do
      # (718 + 207 + 231) / 1000 * 10
      PDF::Fonts::Type1.new("Helvetica").line_height(10.0).should be_close(11.56, 1e-9)
    end
  end

  describe PDF::Fonts::TrueTypeFont do
    it "scales the OS/2 Windows metrics to 1/1000 em" do
      font = PDF::Fonts::TrueTypeFont.load(DEJAVU)
      # DejaVu Sans: 2048 units/em, usWinAscent 1901, usWinDescent 483.
      font.ascender.should eq(928)
      font.descender.should eq(-236)
    end

    it "has no extra line gap when the Windows metrics cover the hhea line height" do
      # hhea: 1901 - (-483) + 0 = 2384 = usWinAscent + usWinDescent
      PDF::Fonts::TrueTypeFont.load(DEJAVU).line_gap.should eq(0)
    end
  end
end
