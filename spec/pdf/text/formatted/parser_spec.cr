require "../../../spec_helper"

private def parse(markup : String)
  PDF::Text::Formatted::Parser.format(markup)
end

private def texts(markup : String) : Array(String)
  parse(markup).map(&.[:text].as(String))
end

describe PDF::Text::Formatted::Parser do
  it "returns plain text as one unstyled fragment" do
    fragments = parse("Hello world")
    fragments.size.should eq(1)
    fragments[0][:text].should eq("Hello world")
    fragments[0][:styles].should eq([] of Symbol)
  end

  it "returns no fragments for an empty string" do
    parse("").should be_empty
  end

  it "maps style tags and their aliases to styles" do
    {
      "b" => :bold, "strong" => :bold, "i" => :italic, "em" => :italic,
      "u" => :underline, "strikethrough" => :strikethrough,
      "sub" => :subscript, "sup" => :superscript,
    }.each do |tag, style|
      parse("<#{tag}>x</#{tag}>").first[:styles].should eq([style])
    end
  end

  it "combines nested styles" do
    fragments = parse("a <b>b <i>c</i></b> d")
    texts("a <b>b <i>c</i></b> d").should eq(["a ", "b ", "c", " d"])
    fragments.map(&.[:styles]).should eq([[] of Symbol, [:bold], [:bold, :italic], [] of Symbol])
  end

  it "does not repeat a style that is nested twice" do
    parse("<b><strong>x</strong></b>").first[:styles].should eq([:bold])
  end

  it "reads the color from the rgb attribute, with either quote" do
    parse(%(<color rgb="FF0000">red</color>)).first[:color].should eq("FF0000")
    parse(%(<color rgb='#00f'>blue</color>)).first[:color].should eq("#00f")
  end

  it "uses the innermost color" do
    fragments = parse(%(<color rgb="FF0000">r<color rgb="00FF00">g</color>r</color>))
    fragments.map(&.[:color]?).should eq(["FF0000", "00FF00", "FF0000"])
  end

  it "reads the font name and size" do
    fragment = parse(%(<font name="Courier" size="9.5">code</font>)).first
    fragment[:font].should eq("Courier")
    fragment[:size].should eq(9.5)
  end

  it "raises for a font size that is not a number" do
    expect_raises(ArgumentError, /font size/) { parse(%(<font size="big">x</font>)) }
  end

  it "raises for a font size that is not positive and finite" do
    # nan wrote "/F1 nan Tf" to the content stream, which is not valid PDF.
    ["nan", "inf", "-inf", "0", "-5", "1e309"].each do |size|
      expect_raises(ArgumentError, /font size/) { parse(%(<font size="#{size}">x</font>)) }
    end
  end

  it "parses tags between multibyte characters" do
    fragments = parse("ü<b>é</b>ö " * 3)
    fragments.map(&.[:text].as(String)).join.should eq("üéö " * 3)
    fragments[1][:text].should eq("é")
    fragments[1][:styles].should eq([:bold])
  end

  it "parses long non-ASCII markup completely" do
    fragments = parse("ü <b>é</b> " * 20_000)
    fragments.size.should eq(40_001)
    fragments.last[:text].should eq(" ")
  end

  it "raises for markup that is not valid UTF-8" do
    invalid = String.new(Bytes[0x61, 0xff, 0x3c, 0x62, 0x3e, 0x62])
    expect_raises(ArgumentError) { parse(invalid) }
  end

  it "converts <br> and <br/> to newlines" do
    texts("a<br>b<br/>c").should eq(["a\nb\nc"])
  end

  it "decodes the &lt; &gt; and &amp; entities once" do
    texts("&lt;b&gt; &amp;amp;").should eq(["<b> &amp;"])
  end

  it "keeps unknown tags and unmatched closing tags as text" do
    texts("<span>x</span> y</b>").should eq(["<span>x</span> y</b>"])
  end

  it "applies an unclosed tag to the end of the string" do
    parse("a <b>rest").last[:styles].should eq([:bold])
  end

  it "accepts tag names in any case" do
    parse("<B>x</B>").first[:styles].should eq([:bold])
  end

  it "renders through Page#formatted_text_box" do
    doc = PDF::Document.new
    doc.page do |page|
      remaining = page.formatted_text_box("plain <b>bold</b>", at: {50, 700}, width: 400)
      remaining.should be_empty
      page.content_string.should contain("(bold)")
      page.content_string.should_not contain("<b>")
    end
  end
end
