require "../../spec_helper"

# Regression specs for the SVG features tracked in issue #4: use/defs,
# tspan and text layout, fonts, CSS, gradients, clipPath, opacity, rounded
# rects, stroke properties, nested viewports and preserveAspectRatio.

private def svg_doc(body : String, attrs : String = %(width="100" height="100")) : String
  %(<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" #{attrs}>#{body}</svg>)
end

# Renders the SVG and returns {content stream, full PDF bytes as text}.
private def render_full(svg : String, **opts) : Tuple(String, String)
  content = ""
  doc = PDF::Document.new
  doc.page do |page|
    page.svg(svg, **opts)
    content = page.content_string
  end
  io = IO::Memory.new
  doc.write(io)
  {content, io.to_s}
end

private def content_of(svg : String, **opts) : String
  render_full(svg, **opts)[0]
end

# Returns the current transformation at the first line that contains
# `marker`, honouring q/Q nesting.
private def ctm_at(content : String, marker : String) : PDF::SVG::Transform::Matrix
  stack = [] of PDF::SVG::Transform::Matrix
  m = PDF::SVG::Transform::IDENTITY
  content.each_line do |line|
    return m if line.includes?(marker)
    if line == "q"
      stack << m
    elsif line == "Q"
      m = stack.pop
    elsif match = line.match(/^(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) cm$/)
      cm = {match[1].to_f, match[2].to_f, match[3].to_f, match[4].to_f, match[5].to_f, match[6].to_f}
      m = PDF::SVG::Transform.multiply(m, cm)
    end
  end
  raise "marker #{marker.inspect} not found in:\n#{content}"
end

private def page_point(content : String, marker : String, x : Float64, y : Float64) : Tuple(Float64, Float64)
  PDF::SVG::Transform.apply(ctm_at(content, marker), x, y)
end

private def should_be_at(actual : Tuple(Float64, Float64), x : Float64, y : Float64)
  actual[0].should be_close(x, 1e-3)
  actual[1].should be_close(y, 1e-3)
end

# The origin of each text run (the flip matrix right before BT), in order.
private def text_origins(content : String) : Array(Tuple(Float64, Float64))
  content.scan(/^1 0 0 -1 (\S+) (\S+) cm\nBT$/m).map { |match| {match[1].to_f, match[2].to_f} }
end

private def shown_text(content : String) : Array(String)
  content.scan(/^\(([^\n]*)\) Tj$/m).map(&.[1])
end

describe "SVG use and defs" do
  it "draws the referenced element translated by x and y" do
    c = content_of(svg_doc(%(<defs><rect id="r" width="5" height="5"/></defs><use href="#r" x="10" y="20"/>)))
    c.should contain("1 0 0 1 10 20 cm")
    c.should contain("0 0 5 5 re")
  end

  it "resolves xlink:href" do
    c = content_of(svg_doc(%(<defs><circle id="c" r="4"/></defs><use xlink:href="#c"/>)))
    c.should contain(" c\n")
  end

  it "does not draw defs content by itself" do
    c = content_of(svg_doc(%(<defs><rect id="r" width="5" height="5"/></defs>)))
    c.should_not contain(" re\nf")
  end

  it "styles the referenced element from the use element" do
    c = content_of(svg_doc(%(<defs><rect id="r" width="5" height="5"/></defs><use href="#r" fill="red"/>)))
    c.should contain("1 0 0 rg")
  end

  it "maps a symbol viewBox into the use width and height" do
    c = content_of(svg_doc(%(<defs><symbol id="s" viewBox="0 0 10 10"><rect id="in" width="10" height="10"/></symbol></defs>) +
                           %(<use href="#s" x="5" y="5" width="50" height="50"/>)), at: {0, 100})
    should_be_at(page_point(c, "0 0 10 10 re", 0.0, 0.0), 5.0, 95.0)
    should_be_at(page_point(c, "0 0 10 10 re", 10.0, 10.0), 55.0, 45.0)
  end

  it "clips a symbol to its viewport" do
    c = content_of(svg_doc(%(<defs><symbol id="s" viewBox="0 0 10 10"><circle r="20"/></symbol></defs><use href="#s" width="30" height="30"/>)))
    c.should contain("0 0 30 30 re\nW\nn\n")
  end

  it "stops at a use element that references its own ancestor" do
    c = content_of(svg_doc(%(<g id="loop"><rect width="1" height="1"/><use href="#loop"/></g>)))
    c.scan("0 0 1 1 re").size.should be < 40
  end
end

describe "SVG text layout" do
  it "places a tspan after the preceding text, with dx and dy" do
    c = content_of(svg_doc(%(<text x="10" y="20">A<tspan dx="5" dy="3">B</tspan></text>)))
    origins = text_origins(c)
    origins[0].should eq({10.0, 20.0})
    width_a = 667 * 12 / 1000.0
    origins[1][0].should be_close(10.0 + width_a + 5.0, 1e-6)
    origins[1][1].should be_close(23.0, 1e-6)
  end

  it "moves to an absolute tspan x and y" do
    c = content_of(svg_doc(%(<text x="10" y="20">A<tspan x="40" y="60">B</tspan></text>)))
    text_origins(c)[1].should eq({40.0, 60.0})
  end

  it "applies x lists per character" do
    c = content_of(svg_doc(%(<text x="10 20 30" y="5">ABC</text>)))
    text_origins(c).map(&.[0]).should eq([10.0, 20.0, 30.0])
    shown_text(c).should eq(%w[A B C])
  end

  it "collapses white space and trims the ends" do
    c = content_of(svg_doc(%(<text>  Hello \n\t  World  </text>)))
    shown_text(c).should eq(["Hello World"])
  end

  it "inherits fill and font-size into a tspan and lets it override them" do
    c = content_of(svg_doc(%(<text fill="red" font-size="20">a<tspan font-size="10">b</tspan><tspan fill="blue">c</tspan></text>)))
    c.should contain("/F1 20 Tf")
    c.should contain("/F1 10 Tf")
    c.scan("1 0 0 rg").size.should eq(2)
    c.should contain("0 0 1 rg")
  end

  it "resolves em font sizes against the parent" do
    c = content_of(svg_doc(%(<text font-size="10">a<tspan font-size="2em">b</tspan></text>)))
    c.should contain("/F1 20 Tf")
  end

  it "centres text with text-anchor middle" do
    c = content_of(svg_doc(%(<text x="50" y="10" text-anchor="middle">Hi</text>)))
    width = (722 + 222) * 12 / 1000.0
    text_origins(c)[0][0].should be_close(50.0 - width / 2.0, 1e-6)
  end

  it "ends text at x with text-anchor end, across tspans" do
    c = content_of(svg_doc(%(<text x="50" y="10" text-anchor="end">H<tspan fill="red">i</tspan></text>)))
    origins = text_origins(c)
    origins[0][0].should be_close(50.0 - (722 + 222) * 12 / 1000.0, 1e-6)
    origins[1][0].should be_close(50.0 - 222 * 12 / 1000.0, 1e-6)
  end

  it "anchors each absolutely positioned chunk separately" do
    c = content_of(svg_doc(%(<text x="50" y="10" text-anchor="end">i<tspan x="80" y="10">i</tspan></text>)))
    text_origins(c).map(&.[0]).map(&.round(3)).should eq([(50 - 2.664).round(3), (80 - 2.664).round(3)])
  end

  it "maps font-family, font-weight and font-style to standard fonts" do
    _, pdf = render_full(svg_doc(
      %(<text font-family="'Times New Roman', serif">a</text>) +
      %(<text font-family="Consolas, monospace" font-weight="bold" font-style="italic">b</text>) +
      %(<text font-family="Unknown Sans" font-weight="700">c</text>)))
    pdf.should contain("/BaseFont /Times-Roman")
    pdf.should contain("/BaseFont /Courier-BoldOblique")
    pdf.should contain("/BaseFont /Helvetica-Bold")
  end
end

describe "SVG style sheets" do
  it "applies class and type rules from a style element" do
    c = content_of(svg_doc(%(<style>rect { fill: blue } .hot { stroke: red }</style><rect class="hot" width="5" height="5"/>)))
    c.should contain("0 0 1 rg")
    c.should contain("1 0 0 RG")
  end

  it "ranks an id rule above a later class rule" do
    c = content_of(svg_doc(%(<style>#x { fill: blue } .a { fill: red }</style><rect id="x" class="a" width="5" height="5"/>)))
    c.should contain("0 0 1 rg")
  end

  it "ranks style sheet rules above presentation attributes" do
    c = content_of(svg_doc(%(<style>.a { fill: blue }</style><rect class="a" fill="red" width="5" height="5"/>)))
    c.should contain("0 0 1 rg")
  end

  it "ranks inline style above rules, and !important above inline style" do
    c = content_of(svg_doc(%(<style>#x { fill: red } .b { fill: lime !important }</style>) +
                           %(<rect id="x" style="fill: blue" width="5" height="5"/><rect class="b" style="fill: blue" width="5" height="5"/>)))
    c.should contain("0 0 1 rg")
    c.should contain("0 1 0 rg")
  end

  it "matches child and descendant combinators" do
    c = content_of(svg_doc(%(<style>g.p > rect { fill: blue } svg rect.d { stroke: red }</style>) +
                           %(<g class="p"><rect class="d" width="5" height="5"/></g><g><g class="p"><g><rect width="5" height="5"/></g></g></g>)))
    c.scan("0 0 1 rg").size.should eq(1)
    c.should contain("1 0 0 RG")
  end

  it "reads CDATA style sheets inside defs and lets rules inherit" do
    c = content_of(svg_doc(%(<defs><style><![CDATA[ .g { fill: lime } ]]></style></defs><g class="g"><rect width="5" height="5"/></g>)))
    c.should contain("0 1 0 rg")
  end
end

describe "SVG gradients" do
  linear = %(<defs><linearGradient id="g"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs>)

  it "fills with an axial shading clipped to the shape" do
    c, pdf = render_full(svg_doc(linear + %(<rect x="10" y="20" width="100" height="50" fill="url(#g)"/>)))
    c.should contain("10 20 100 50 re\nW\nn\n")
    c.should contain("100 0 0 50 10 20 cm\n/Sh1 sh\n")
    pdf.should contain("/ShadingType 2")
    pdf.should contain("/Coords [0 0 1 0]")
    pdf.should contain("/C0 [1 0 0]/C1 [0 0 1]")
    pdf.should contain("/Shading <</Sh1")
  end

  it "uses user space coordinates with userSpaceOnUse" do
    _, pdf = render_full(svg_doc(%(<defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" x2="50%" y2="10"><stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs>) +
                                 %(<rect width="10" height="10" fill="url(#g)"/>)))
    pdf.should contain("/Coords [0 0 50 10]")
  end

  it "applies gradientTransform after the bounding box mapping" do
    c = content_of(svg_doc(%(<defs><linearGradient id="g" gradientTransform="rotate(90)"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs>) +
                           %(<rect width="10" height="20" fill="url(#g)"/>)))
    # bbox(10 x 20) * rotate(90)
    c.should contain("0 20 -10 0 0 0 cm\n/Sh1 sh")
  end

  it "builds a radial shading with the focal point" do
    _, pdf = render_full(svg_doc(%(<defs><radialGradient id="r" fx="0.25"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></radialGradient></defs>) +
                                 %(<circle cx="10" cy="10" r="10" fill="url(#r)"/>)))
    pdf.should contain("/ShadingType 3")
    pdf.should contain("/Coords [0.25 0.5 0 0.5 0.5 0.5]")
  end

  it "stitches more than two stops and inherits stops through href" do
    _, pdf = render_full(svg_doc(%(<defs><linearGradient id="base"><stop offset="0" stop-color="red"/><stop offset="50%" stop-color="lime"/><stop offset="1" stop-color="blue"/></linearGradient>) +
                                 %(<linearGradient id="g" href="#base" x2="0" y2="1"/></defs><rect width="5" height="5" fill="url(#g)"/>)))
    pdf.should contain("/FunctionType 3")
    pdf.should contain("/Bounds [0.5]")
    pdf.should contain("/Coords [0 0 0 1]")
  end

  it "adds a luminosity soft mask for translucent stops" do
    c, pdf = render_full(svg_doc(%(<defs><linearGradient id="g"><stop stop-color="red" stop-opacity="1"/><stop offset="1" stop-color="red" style="stop-opacity: 0"/></linearGradient></defs>) +
                                 %(<rect width="10" height="10" fill="url(#g)"/>)))
    c.should match(/W\nn\n\/GS1 gs\n10 0 0 10 0 0 cm\n\/Sh1 sh/)
    pdf.should contain("/S /Luminosity")
    pdf.should contain("/ColorSpace /DeviceGray")
    pdf.should contain("/C0 [1]/C1 [0]")
    pdf.should contain("/CS /DeviceGray")
  end

  it "has no soft mask when all stops are opaque" do
    _, pdf = render_full(svg_doc(linear + %(<rect width="10" height="10" fill="url(#g)"/>)))
    pdf.should_not contain("/SMask")
  end

  it "multiplies fill-opacity and stop-opacity alpha from rgba colors" do
    _, pdf = render_full(svg_doc(%(<defs><linearGradient id="g"><stop stop-color="rgba(255,0,0,0.5)"/><stop offset="1" stop-color="red"/></linearGradient></defs>) +
                                 %(<rect width="10" height="10" fill="url(#g)" fill-opacity="0.5"/>)))
    pdf.should contain("/C0 [0.5]/C1 [1]")
    pdf.should contain("/ca 0.5")
  end

  it "paints a single-stop gradient as a solid color" do
    c = content_of(svg_doc(%(<defs><linearGradient id="g"><stop stop-color="blue"/></linearGradient></defs><rect width="5" height="5" fill="url(#g)"/>)))
    c.should contain("0 0 1 rg")
    c.should_not contain(" sh")
  end

  it "uses the fallback color when the url does not resolve" do
    c = content_of(svg_doc(%(<rect width="5" height="5" fill="url(#missing) red"/>)))
    c.should contain("1 0 0 rg")
  end

  it "strokes with a shading pattern placed in page space" do
    c, pdf = render_full(svg_doc(linear + %(<rect width="10" height="10" fill="none" stroke="url(#g)"/>)), at: {0, 100})
    c.should contain("/Pattern CS /P1 SCN\n")
    pdf.should contain("/PatternType 2")
    # root (1, -1, 0, 100) * bbox (10, 10, 0, 0)
    pdf.should contain("/Matrix [10 0 0 -10 0 100]")
  end
end

describe "SVG clipPath" do
  it "clips to the clip path outline in the element's user space" do
    c = content_of(svg_doc(%(<defs><clipPath id="c"><rect x="1" y="2" width="3" height="4"/></clipPath></defs>) +
                           %(<g transform="translate(5,5)" clip-path="url(#c)"><circle r="50" fill="red"/></g>)))
    c.should match(/1 0 0 1 5 5 cm\n1 2 3 4 re\nW\nn\n/)
    ctm_at(c, "1 2 3 4 re").should eq(ctm_at(c, "1 0 0 rg"))
  end

  it "applies the transforms of clip path children to their points" do
    c = content_of(svg_doc(%(<defs><clipPath id="c"><rect transform="translate(10,0)" width="2" height="2"/></clipPath></defs>) +
                           %(<rect width="50" height="50" clip-path="url(#c)"/>)))
    c.should contain("10 0 m\n12 0 l\n12 2 l\n10 2 l\nh\nW\nn\n")
  end

  it "scales objectBoundingBox clip paths to the element's box" do
    c = content_of(svg_doc(%(<defs><clipPath id="c" clipPathUnits="objectBoundingBox"><polygon points="0,0 1,0 1,1"/></clipPath></defs>) +
                           %(<rect x="10" y="10" width="100" height="50" clip-path="url(#c)"/>)))
    c.should contain("10 10 m\n110 10 l\n110 60 l\nh\nW\nn\n")
  end

  it "uses the even-odd rule for clip-rule evenodd" do
    c = content_of(svg_doc(%(<defs><clipPath id="c"><path d="M0 0 H10 V10 Z" clip-rule="evenodd"/></clipPath></defs><rect width="5" height="5" clip-path="url(#c)"/>)))
    c.should contain("W*\nn\n")
  end

  it "clips everything away for an empty clip path" do
    c = content_of(svg_doc(%(<defs><clipPath id="c"/></defs><rect width="5" height="5" clip-path="url(#c)"/>)))
    c.should contain("0 0 0 0 re\nW\nn\n")
  end
end

describe "SVG opacity" do
  it "emits fill-opacity and stroke-opacity through an ExtGState" do
    c, pdf = render_full(svg_doc(%(<rect width="5" height="5" fill="red" stroke="blue" fill-opacity="0.5" stroke-opacity="25%"/>)))
    c.should contain("/GS1 gs")
    pdf.should contain("/ca 0.5")
    pdf.should contain("/CA 0.25")
  end

  it "multiplies group opacity into the children" do
    _, pdf = render_full(svg_doc(%(<g opacity="0.5"><g opacity="0.5"><rect width="5" height="5" fill-opacity="0.5"/></g></g>)))
    pdf.should contain("/ca 0.125")
  end

  it "uses the alpha of rgba colors" do
    _, pdf = render_full(svg_doc(%(<rect width="5" height="5" fill="rgba(0, 0, 255, 0.4)"/>)))
    pdf.should contain("/ca 0.4")
  end

  it "does not emit a graphics state when everything is opaque" do
    c = content_of(svg_doc(%(<rect width="5" height="5" opacity="1"/>)))
    c.should_not contain(" gs")
  end
end

describe "SVG rounded rects" do
  it "draws elliptical corners with rx and ry" do
    c = content_of(svg_doc(%(<rect x="0" y="0" width="40" height="20" rx="10" ry="5"/>)))
    c.should contain("10 0 m\n30 0 l\n")
    c.should contain(" 40 5 c\n")
    c.should_not contain("0 0 40 20 re")
  end

  it "uses rx for a missing ry and clamps to half the size" do
    c = content_of(svg_doc(%(<rect width="40" height="20" rx="30"/>)))
    # rx clamps to 20, ry = rx clamps to 10
    c.should contain("20 0 m\n20 0 l\n")
    c.should contain(" 40 10 c\n")
  end

  it "keeps a plain rectangle when rx and ry are zero" do
    c = content_of(svg_doc(%(<rect width="40" height="20" rx="0"/>)))
    c.should contain("0 0 40 20 re")
  end
end

describe "SVG stroke properties" do
  it "emits dash arrays, repeating odd lists, with the dash offset" do
    c = content_of(svg_doc(%(<line x2="10" stroke="red" stroke-dasharray="5,3"/><line x2="10" stroke="red" stroke-dasharray="4" stroke-dashoffset="2"/>)))
    c.should contain("[5 3] 0 d")
    c.should contain("[4 4] 2 d")
  end

  it "ignores dash arrays that are none, negative or all zero" do
    c = content_of(svg_doc(%(<line x2="1" stroke="red" stroke-dasharray="none"/><line x2="1" stroke="red" stroke-dasharray="3 -1"/><line x2="1" stroke="red" stroke-dasharray="0 0"/>)))
    c.should_not contain(" d\n")
  end

  it "emits caps, joins and the miter limit, inherited from groups" do
    c = content_of(svg_doc(%(<g stroke="black" stroke-linecap="round" stroke-linejoin="bevel" stroke-miterlimit="8" stroke-dasharray="2 1"><polyline points="0,0 5,5 10,0" fill="none"/></g>)))
    c.should contain("1 J")
    c.should contain("2 j")
    c.should contain("8 M")
    c.should contain("[2 1] 0 d")
  end

  it "does not stroke when stroke-width is zero" do
    c = content_of(svg_doc(%(<rect width="5" height="5" fill="none" stroke="red" stroke-width="0"/>)))
    c.should_not contain("RG")
    c.should_not contain("\nS\n")
  end
end

describe "SVG nested viewports" do
  it "maps a nested svg viewBox into its x, y, width and height, and clips" do
    c = content_of(svg_doc(%(<svg x="10" y="20" width="40" height="40" viewBox="0 0 4 4"><rect id="a" width="4" height="4"/></svg>)), at: {0, 100})
    c.should contain("10 20 40 40 re\nW\nn\n")
    should_be_at(page_point(c, "0 0 4 4 re", 0.0, 0.0), 10.0, 80.0)
    should_be_at(page_point(c, "0 0 4 4 re", 4.0, 4.0), 50.0, 40.0)
  end

  it "resolves percentages against the nearest viewport" do
    c = content_of(svg_doc(%(<svg x="0" y="0" width="50" height="20"><rect width="50%" height="100%"/></svg>)))
    c.should contain("0 0 25 20 re")
  end

  it "does not clip with overflow visible" do
    c = content_of(svg_doc(%(<svg width="10" height="10" overflow="visible"><rect width="50" height="50"/></svg>)))
    c.should_not contain("0 0 10 10 re")
  end
end

describe "SVG preserveAspectRatio" do
  it "clips the root drawing to the output box" do
    c = content_of(svg_doc(%(<rect width="5" height="5"/>)), at: {50, 700})
    c.should start_with("q\n50 600 100 100 re\nW\nn\n")
  end

  it "covers the root viewport with slice" do
    c = content_of(svg_doc(%(<rect width="100" height="50"/>), %(width="100" height="100" viewBox="0 0 100 50" preserveAspectRatio="xMidYMid slice")), at: {0, 100})
    should_be_at(page_point(c, "0 0 100 50 re", 0.0, 0.0), -50.0, 100.0)
    should_be_at(page_point(c, "0 0 100 50 re", 100.0, 50.0), 150.0, 0.0)
  end

  it "stretches the root viewBox with none" do
    c = content_of(svg_doc(%(<rect width="10" height="10"/>), %(width="100" height="50" viewBox="0 0 10 10" preserveAspectRatio="none")), at: {0, 50})
    should_be_at(page_point(c, "0 0 10 10 re", 10.0, 10.0), 100.0, 0.0)
  end

  it "aligns with xMaxYMax meet" do
    c = content_of(svg_doc(%(<rect width="10" height="10"/>), %(width="100" height="50" viewBox="0 0 10 10" preserveAspectRatio="xMaxYMax meet")), at: {0, 50})
    should_be_at(page_point(c, "0 0 10 10 re", 0.0, 0.0), 50.0, 50.0)
  end
end

describe PDF::SVG::AspectRatio do
  vb = {0.0, 0.0, 20.0, 10.0}

  it "defaults to xMidYMid meet, also for invalid values" do
    {nil, "bogus", "xMidYMid wrong"}.each do |value|
      PDF::SVG::AspectRatio.parse(value).transform(vb, 0.0, 0.0, 40.0, 40.0).should eq({2.0, 0.0, 0.0, 2.0, 0.0, 10.0})
    end
  end

  it "aligns min and max with meet and slice" do
    PDF::SVG::AspectRatio.parse("xMinYMin").transform(vb, 0.0, 0.0, 40.0, 40.0).should eq({2.0, 0.0, 0.0, 2.0, 0.0, 0.0})
    PDF::SVG::AspectRatio.parse("xMaxYMax slice").transform(vb, 0.0, 0.0, 40.0, 40.0).should eq({4.0, 0.0, 0.0, 4.0, -40.0, 0.0})
  end

  it "scales each axis with none and honours the viewport origin and viewBox minimum" do
    PDF::SVG::AspectRatio.parse("none").transform({5.0, 5.0, 20.0, 10.0}, 1.0, 2.0, 40.0, 40.0).should eq({2.0, 0.0, 0.0, 4.0, -9.0, -18.0})
  end

  it "skips the defer keyword" do
    PDF::SVG::AspectRatio.parse("defer xMinYMin slice").slice?.should be_true
  end
end

describe PDF::SVG::Geometry do
  it "measures curve extrema in the bounding box" do
    box = PDF::SVG::Geometry.bbox(PDF::SVG::PathParser.parse("M0 0 C0 10 10 10 10 0")).should_not be_nil
    box[3].should be_close(7.5, 1e-9)
  end

  it "turns rectangles into polygons when transformed" do
    cmds = PDF::SVG::Geometry.transform(PDF::SVG::Geometry.rect(0.0, 0.0, 2.0, 1.0), {0.0, 1.0, -1.0, 0.0, 0.0, 0.0})
    cmds.map(&.type).should eq(['M', 'L', 'L', 'L', 'Z'])
    cmds[2].args.should eq([-1.0, 2.0])
  end
end

describe PDF::SVG::FontMap do
  it "uses the first known family and falls back to Helvetica" do
    PDF::SVG::FontMap.resolve("Nope, 'Courier New', serif").should eq("Courier")
    PDF::SVG::FontMap.resolve("Nope").should eq("Helvetica")
    PDF::SVG::FontMap.resolve(nil, "600", "oblique").should eq("Helvetica-BoldOblique")
    PDF::SVG::FontMap.resolve("serif", "normal", "italic").should eq("Times-Italic")
    PDF::SVG::FontMap.resolve("Symbol", "bold").should eq("Symbol")
  end
end

describe PDF::SVG::Color do
  it "parses rgba, #RGBA, #RRGGBBAA, percentages and transparent" do
    PDF::SVG::Color.parse_rgba("rgba(255, 0, 0, 0.25)").should eq({1.0, 0.0, 0.0, 0.25})
    PDF::SVG::Color.parse_rgba("#f008").should eq({1.0, 0.0, 0.0, 8 / 15.0})
    PDF::SVG::Color.parse_rgba("#0000ff80").should eq({0.0, 0.0, 1.0, 128 / 255.0})
    PDF::SVG::Color.parse_rgba("rgb(100%, 50%, 0%)").should eq({1.0, 0.5, 0.0, 1.0})
    PDF::SVG::Color.parse_rgba("transparent").should eq({0.0, 0.0, 0.0, 0.0})
    PDF::SVG::Color.parse_rgba("red").should eq({1.0, 0.0, 0.0, 1.0})
  end
end

describe "PDF::Page shadings and patterns" do
  it "registers shading and pattern resources and emits their operators" do
    doc = PDF::Document.new
    content = ""
    doc.page do |page|
      shading = PDF::Objects::Dictionary.new
      shading["ShadingType"] = PDF::Objects::Number.new(2)
      key = page.register_shading(shading)
      key.should eq("Sh1")
      page.shade(key)
      pattern = PDF::Objects::Dictionary.new
      pattern["PatternType"] = PDF::Objects::Number.new(2)
      pkey = page.register_pattern(pattern)
      pkey.should eq("P1")
      page.fill_pattern(pkey)
      page.stroke_pattern(pkey)
      content = page.content_string
    end
    content.should eq("/Sh1 sh\n/Pattern cs /P1 scn\n/Pattern CS /P1 SCN\n")
    io = IO::Memory.new
    doc.write(io)
    pdf = io.to_s.scrub
    pdf.should match(/\/Shading <<\/Sh1 \d+ 0 R>>/)
    pdf.should match(/\/Pattern <<\/P1 \d+ 0 R>>/)
  end

  it "keeps ExtGStates with different soft masks apart" do
    doc = PDF::Document.new
    doc.page do |page|
      a = PDF::Objects::ExtGState.new
      a.soft_mask = PDF::Objects::Name.new("None")
      b = PDF::Objects::ExtGState.new
      b.soft_mask = PDF::Objects::Name.new("Other")
      page.apply_graphics_state(a)
      page.apply_graphics_state(b)
      page.content_string.should eq("/GS1 gs\n/GS2 gs\n")
    end
  end
end

describe "SVG edge cases found in review" do
  it "clips to the union of overlapping clipPath children" do
    c = content_of(svg_doc(%(<defs><clipPath id="c"><rect width="20" height="20"/><circle cx="12" cy="10" r="8"/></clipPath></defs>) +
                           %(<rect width="40" height="20" clip-path="url(#c)"/>)))
    # The rect already has a positive signed area; the circle is reversed
    # to match, so the overlap has winding 2 instead of 0.
    c.should contain("0 0 m\n20 0 l\n20 20 l\n0 20 l\nh\n4 10 m\n")
    c.should match(/4 10 m\n\S+ \S+ \S+ \S+ 12 2 c\n/)
    c.should_not contain("W*")
  end

  it "reverses subpaths without changing their shape" do
    cmds = PDF::SVG::PathParser.parse("M0 0 L10 0 C10 5 5 10 0 10 Z")
    reversed = PDF::SVG::Geometry.reverse(cmds)
    reversed.map(&.type).should eq(['M', 'C', 'L', 'Z'])
    reversed[1].args.should eq([5.0, 10.0, 10.0, 5.0, 10.0, 0.0])
    PDF::SVG::Geometry.signed_area(reversed).should eq(-PDF::SVG::Geometry.signed_area(cmds))
  end

  it "keeps the x of a tspan that follows white space in a previous tspan" do
    c = content_of(svg_doc(%(<text y="20"><tspan>a </tspan><tspan x="50">b</tspan></text>)))
    text_origins(c).last.should eq({50.0, 20.0})
    shown_text(c).should eq(%w[a b])
  end

  it "does not widen an anchored chunk with the space before the next chunk" do
    c = content_of(svg_doc(%(<text y="20" text-anchor="end"><tspan x="50">i</tspan>\n<tspan x="80">i</tspan></text>)))
    text_origins(c).map(&.[0].round(3)).should eq([(50 - 2.664).round(3), (80 - 2.664).round(3)])
  end

  it "resolves em in text positions against the font size" do
    c = content_of(svg_doc(%(<text x="5" y="20" font-size="10"><tspan x="5">a</tspan><tspan x="5" dy="1.2em">b</tspan></text>)))
    text_origins(c).last[1].should be_close(32.0, 1e-9)
  end

  it "draws the first supported child of a switch" do
    c = content_of(svg_doc(%(<switch><foreignObject width="10" height="10"/><rect width="3" height="3"/></switch>)))
    c.should contain("0 0 3 3 re")
  end

  it "falls back to the viewBox or default size for percentage dimensions" do
    PDF::SVG::Parser.new(%(<svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg"/>)).width.should eq(300.0)
    parser = PDF::SVG::Parser.new(%(<svg width="100%" viewBox="0 0 40 20" xmlns="http://www.w3.org/2000/svg"/>))
    {parser.width, parser.height}.should eq({40.0, 20.0})
    content_of(%(<svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1"/></svg>)).should contain("0 0 1 1 re")
  end

  it "skips shapes with non-finite numbers" do
    c = content_of(svg_doc(%(<circle cx="1" cy="1" r="nan"/><rect width="1e999" height="5"/>)))
    c.downcase.should_not contain("nan")
    c.downcase.should_not contain("inf")
  end

  it "drops zero-width intervals from hard color stops" do
    _, pdf = render_full(svg_doc(%(<defs><linearGradient id="g"><stop offset="0" stop-color="red"/><stop offset="0.5" stop-color="red"/>) +
                                 %(<stop offset="0.5" stop-color="blue"/><stop offset="1" stop-color="blue"/></linearGradient></defs><rect width="5" height="5" fill="url(#g)"/>)))
    pdf.should contain("/Bounds [0.5]")
  end

  it "resolves currentColor in stops" do
    _, pdf = render_full(svg_doc(%(<defs><linearGradient id="g" color="blue"><stop stop-color="currentColor"/><stop offset="1" stop-color="red"/></linearGradient></defs><rect width="5" height="5" fill="url(#g)"/>)))
    pdf.should contain("/C0 [0 0 1]")
  end
end
