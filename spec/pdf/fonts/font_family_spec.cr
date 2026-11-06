require "../../spec_helper"

private DEJAVU = "#{__DIR__}/../../fixtures/fonts/DejaVuSans.ttf"

private def type1(name : String) : PDF::Fonts::Type1
  PDF::Fonts::Type1.new(name)
end

describe PDF::Fonts::FontFamily do
  it "returns each registered variant" do
    regular, bold, italic, bold_italic = type1("Times-Roman"), type1("Times-Bold"), type1("Times-Italic"), type1("Times-BoldItalic")
    family = PDF::Fonts::FontFamily.new("Serif", normal: regular, bold: bold, italic: italic, bold_italic: bold_italic)
    family.variant(bold: false, italic: false).should be(regular)
    family.variant(bold: true, italic: false).should be(bold)
    family.variant(bold: false, italic: true).should be(italic)
    family.variant(bold: true, italic: true).should be(bold_italic)
  end

  it "falls back to the closest registered variant" do
    regular, italic = type1("Times-Roman"), type1("Times-Italic")
    family = PDF::Fonts::FontFamily.new("Serif", normal: regular, italic: italic)
    family.variant(bold: true, italic: false).should be(regular)
    family.variant(bold: true, italic: true).should be(italic)
  end
end

describe "PDF::Document font families" do
  it "loads TrueType variants from paths" do
    doc = PDF::Document.new
    family = doc.font_family("DejaVu", normal: DEJAVU)
    family.normal.should be_a(PDF::Fonts::TrueTypeFont)
    doc.font_families["DejaVu"].should be(family)
  end

  it "accepts standard 14 font names and font objects as variants" do
    doc = PDF::Document.new
    bold = PDF::Fonts::TrueTypeFont.load(DEJAVU)
    doc.font_family("Mixed", normal: "Helvetica", bold: bold)
    doc.font("Mixed", bold: false, italic: false).name.should eq("Helvetica")
    doc.font("Mixed", bold: true, italic: false).should be(bold)
  end

  it "resolves standard 14 styles without a registered family" do
    doc = PDF::Document.new
    doc.font("Courier", bold: true, italic: true).name.should eq("Courier-BoldOblique")
    doc.font("Times", bold: false, italic: false).name.should eq("Times-Roman")
  end

  it "lets a registered family replace a standard 14 base name" do
    doc = PDF::Document.new
    doc.font_family("Helvetica", normal: DEJAVU)
    doc.font("Helvetica", bold: true, italic: false).should be_a(PDF::Fonts::TrueTypeFont)
  end
end
