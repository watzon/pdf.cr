require "../spec_helper"

private DEJAVU = "#{__DIR__}/../fixtures/fonts/DejaVuSans.ttf"

private def font_keys(page : PDF::Page) : Array(String)
  page.content_string.scan(/\/(F\d+) [\d.]+ Tf/).map(&.[1])
end

describe "PDF::Page font resources" do
  it "gives a Type1 font registered after a TrueType font its own key" do
    doc = PDF::Document.new
    ttf = doc.load_font(DEJAVU)
    doc.page do |page|
      page.font(ttf, size: 12)
      page.text("unicode", at: {72, 720})
      page.font("Helvetica", size: 12)
      page.text("type1", at: {72, 700})
      page.font("Helvetica-Bold", size: 12)
      page.text("bold", at: {72, 680})

      keys = font_keys(page)
      keys.size.should eq(3)
      keys.uniq!.size.should eq(3)
    end
    pdf = String.new(doc.to_slice)
    pdf.should contain("/BaseFont /Helvetica/")
    pdf.should contain("/BaseFont /Helvetica-Bold/")
  end

  it "keeps the key of a font that is used again" do
    doc = PDF::Document.new
    ttf = doc.load_font(DEJAVU)
    doc.page do |page|
      page.font("Helvetica", size: 12)
      page.font(ttf, size: 12)
      page.font("Helvetica", size: 10)
      page.text("again", at: {72, 720})
      page.content_string.should contain("/F1 10 Tf")
    end
  end
end
