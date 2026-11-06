require "../../spec_helper"

describe PDF::SVG::Parser do
  describe "#initialize" do
    it "parses SVG dimensions" do
      svg = %(<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg"></svg>)
      parser = PDF::SVG::Parser.new(svg)
      parser.width.should eq(200.0)
      parser.height.should eq(100.0)
    end

    it "parses SVG with viewBox" do
      svg = %(<svg viewBox="0 0 400 300" xmlns="http://www.w3.org/2000/svg"></svg>)
      parser = PDF::SVG::Parser.new(svg)
      vb = parser.viewbox
      vb.should_not be_nil
      vb = vb.not_nil!
      vb[0].should eq(0.0)
      vb[1].should eq(0.0)
      vb[2].should eq(400.0)
      vb[3].should eq(300.0)
    end

    it "defaults dimensions when not specified" do
      svg = %(<svg xmlns="http://www.w3.org/2000/svg"></svg>)
      parser = PDF::SVG::Parser.new(svg)
      parser.width.should eq(300.0)
      parser.height.should eq(150.0)
    end

    it "parses dimensions with units" do
      svg = %(<svg width="2in" height="3cm" xmlns="http://www.w3.org/2000/svg"></svg>)
      parser = PDF::SVG::Parser.new(svg)
      parser.width.should be_close(144.0, 0.1)  # 2 * 72
      parser.height.should be_close(85.04, 0.1) # 3 * 28.3465
    end
  end

  describe "#elements" do
    it "returns child elements" do
      svg = %(<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/><circle cx="5" cy="5" r="3"/></svg>)
      parser = PDF::SVG::Parser.new(svg)
      parser.elements.size.should eq(2)
    end
  end

  describe ".parse_length" do
    it "parses pixel values" do
      PDF::SVG::Parser.parse_length("100px").should eq(100.0)
    end

    it "parses point values" do
      PDF::SVG::Parser.parse_length("72pt").should eq(72.0)
    end

    it "parses inch values" do
      PDF::SVG::Parser.parse_length("1in").should eq(72.0)
    end

    it "parses cm values" do
      result = PDF::SVG::Parser.parse_length("1cm")
      result.should_not be_nil
      result.not_nil!.should be_close(28.3465, 0.01)
    end

    it "parses mm values" do
      result = PDF::SVG::Parser.parse_length("10mm")
      result.should_not be_nil
      result.not_nil!.should be_close(28.3465, 0.01)
    end

    it "parses bare numbers" do
      PDF::SVG::Parser.parse_length("42").should eq(42.0)
    end

    it "returns nil for nil input" do
      PDF::SVG::Parser.parse_length(nil).should be_nil
    end

    it "returns nil for empty string" do
      PDF::SVG::Parser.parse_length("").should be_nil
    end
  end
end

describe PDF::SVG::Renderer do
  describe "#draw" do
    it "renders a simple SVG with a rectangle" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="40" fill="blue" stroke="black" stroke-width="2"/>
        </svg>)
        renderer = page.svg(svg, at: {50, 700})
        renderer.output_width.should eq(200.0)
        renderer.output_height.should eq(100.0)
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "renders an SVG with a circle" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
          <circle cx="50" cy="50" r="40" fill="red"/>
        </svg>)
        page.svg(svg, at: {50, 700})
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "renders an SVG with a line" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
          <line x1="0" y1="0" x2="200" y2="200" stroke="green" stroke-width="3"/>
        </svg>)
        page.svg(svg, at: {50, 700})
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "renders an SVG with a polygon" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
          <polygon points="100,10 40,198 190,78 10,78 160,198" fill="gold" stroke="black"/>
        </svg>)
        page.svg(svg, at: {50, 700})
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "renders an SVG with a path" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
          <path d="M 10 80 C 40 10, 65 10, 95 80 S 150 150, 180 80" fill="none" stroke="purple" stroke-width="2"/>
        </svg>)
        page.svg(svg, at: {50, 700})
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "renders an SVG with a group and transform" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
          <g transform="translate(50, 50)">
            <rect x="0" y="0" width="50" height="50" fill="orange"/>
          </g>
        </svg>)
        page.svg(svg, at: {50, 700})
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "applies a transform set directly on a shape, not just on <g>" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
          <rect transform="translate(20, 30)" x="0" y="0" width="10" height="10" fill="orange"/>
        </svg>)
        page.svg(svg, at: {50, 700})
        # Root cm maps SVG space to the page; the element cm is the plain SVG matrix.
        page.content_string.should contain("1 0 0 1 20 30 cm")
        page.content_string.should_not contain("1 0 0 1 70 670 cm")
      end
    end

    it "renders an SVG with text" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" fill="black" font-size="16">Hello SVG</text>
        </svg>)
        page.svg(svg, at: {50, 700})
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "renders an SVG with custom dimensions" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="200" height="100" fill="lightblue"/>
        </svg>)
        renderer = page.svg(svg, at: {50, 700}, width: 400.0, height: 200.0)
        renderer.output_width.should eq(400.0)
        renderer.output_height.should eq(200.0)
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "renders an SVG with inline styles" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="80" height="40" style="fill:red;stroke:blue;stroke-width:3"/>
        </svg>)
        page.svg(svg, at: {50, 700})
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "renders an SVG with an ellipse" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="100" cy="50" rx="80" ry="40" fill="green"/>
        </svg>)
        page.svg(svg, at: {50, 700})
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "renders an SVG with a polyline" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 10)
        svg = %(<svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
          <polyline points="0,40 40,40 40,80 80,80 80,120 120,120" fill="none" stroke="black" stroke-width="2"/>
        </svg>)
        page.svg(svg, at: {50, 700})
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end
  end
end

# Composes every `a b c d e f cm` line (in order, as nested transforms) and
# maps an SVG point to page coordinates.
private def svg_point_on_page(content : String, x : Float64, y : Float64) : Tuple(Float64, Float64)
  m = PDF::SVG::Transform::IDENTITY
  content.scan(/^(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) cm$/m) do |match|
    cm = {match[1].to_f, match[2].to_f, match[3].to_f, match[4].to_f, match[5].to_f, match[6].to_f}
    m = PDF::SVG::Transform.multiply(m, cm)
  end
  PDF::SVG::Transform.apply(m, x, y)
end

private def render_svg(svg : String, **opts) : String
  content = ""
  doc = PDF::Document.new
  doc.page do |page|
    page.svg(svg, **opts)
    content = page.content_string
  end
  content
end

private def expect_pt(actual : Tuple(Float64, Float64), x : Float64, y : Float64)
  actual[0].should be_close(x, 1e-3)
  actual[1].should be_close(y, 1e-3)
end

describe "SVG coordinate mapping" do
  rect_svg = ->(attrs : String, body : String) {
    %(<svg width="100" height="100" #{attrs} xmlns="http://www.w3.org/2000/svg">#{body}</svg>)
  }

  it "maps a plain rect with at: {50, 700} onto x 50..90, y 680..700" do
    c = render_svg(rect_svg.call("", %(<rect x="0" y="0" width="40" height="20"/>)), at: {50, 700})
    c.should contain("0 0 40 20 re")
    expect_pt(svg_point_on_page(c, 0.0, 0.0), 50.0, 700.0)
    expect_pt(svg_point_on_page(c, 40.0, 20.0), 90.0, 680.0)
  end

  it "applies a translate transform once, without the at: offset" do
    c = render_svg(rect_svg.call("", %(<rect transform="translate(10,10)" width="40" height="20"/>)), at: {50, 700})
    expect_pt(svg_point_on_page(c, 0.0, 0.0), 60.0, 690.0)
    expect_pt(svg_point_on_page(c, 40.0, 20.0), 100.0, 670.0)
  end

  it "rotates about the SVG origin, not the page origin" do
    c = render_svg(rect_svg.call("", %(<rect transform="rotate(90)" width="40" height="20"/>)), at: {50, 700})
    # rotate(90): (x, y) -> (-y, x) in SVG space
    expect_pt(svg_point_on_page(c, 40.0, 0.0), 50.0, 660.0)
    expect_pt(svg_point_on_page(c, 0.0, 20.0), 30.0, 700.0)
  end

  it "honours viewBox min-x and min-y" do
    c = render_svg(rect_svg.call(%(viewBox="10 10 50 50"), %(<rect x="10" y="10" width="5" height="5"/>)), at: {50, 700}, width: 50.0, height: 50.0)
    expect_pt(svg_point_on_page(c, 10.0, 10.0), 50.0, 700.0)
    expect_pt(svg_point_on_page(c, 60.0, 60.0), 100.0, 650.0)
  end

  it "derives the height from the aspect ratio when only width is given" do
    doc = PDF::Document.new
    renderer = nil
    c = ""
    doc.page do |page|
      renderer = page.svg(%(<svg width="100" height="50" xmlns="http://www.w3.org/2000/svg"><rect width="100" height="50"/></svg>), at: {0, 100}, width: 200.0)
      c = page.content_string
    end
    renderer.not_nil!.output_height.should eq(100.0)
    expect_pt(svg_point_on_page(c, 100.0, 50.0), 200.0, 0.0)
    expect_pt(svg_point_on_page(c, 0.0, 0.0), 0.0, 100.0)
  end

  it "derives the width from the aspect ratio when only height is given" do
    c = render_svg(%(<svg width="100" height="50" xmlns="http://www.w3.org/2000/svg"><rect width="100" height="50"/></svg>), at: {0, 100}, height: 100.0)
    expect_pt(svg_point_on_page(c, 100.0, 50.0), 200.0, 0.0)
  end

  it "centres the content when width and height differ in aspect (meet)" do
    c = render_svg(%(<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100"/></svg>), at: {0, 100}, width: 200.0, height: 100.0)
    expect_pt(svg_point_on_page(c, 0.0, 0.0), 50.0, 100.0)
    expect_pt(svg_point_on_page(c, 100.0, 100.0), 150.0, 0.0)
  end

  it "does not scale stroke width manually" do
    c = render_svg(rect_svg.call("", %(<rect width="10" height="10" fill="none" stroke="black" stroke-width="3"/>)), at: {0, 100}, width: 200.0)
    c.should contain("3 w")
  end

  it "draws text un-flipped at its position" do
    c = render_svg(rect_svg.call("", %(<text x="10" y="50" font-size="16">Hi</text>)), at: {50, 700})
    c.should contain("1 0 0 -1 10 50 cm")
    c.should contain("0 0 Td")
    # Net y scale of glyph space is positive on the page.
    m = PDF::SVG::Transform::IDENTITY
    c.scan(/^(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) cm$/m) do |match|
      m = PDF::SVG::Transform.multiply(m, {match[1].to_f, match[2].to_f, match[3].to_f, match[4].to_f, match[5].to_f, match[6].to_f})
    end
    m[3].should be > 0
    expect_pt(svg_point_on_page(c, 0.0, 0.0), 60.0, 650.0)
  end
end

describe "SVG painting defaults and inheritance" do
  svg = ->(body : String) { %(<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">#{body}</svg>) }

  it "does not stroke a line without a stroke" do
    c = render_svg(svg.call(%(<line x1="0" y1="0" x2="10" y2="10"/>)))
    c.should_not contain("\nS\n")
    c.should_not contain(" l\n")
  end

  it "strokes a line that has a stroke" do
    c = render_svg(svg.call(%(<line x1="0" y1="0" x2="10" y2="10" stroke="red"/>)))
    c.should contain("10 10 l\nS\n")
  end

  it "closes a path with h and fills it without an outline by default" do
    c = render_svg(svg.call(%(<path d="M0 0 L10 0 L10 10 Z"/>)))
    c.should contain("h\nf\n")
    c.should_not contain("s\n")
    c.should_not contain("B\n")
  end

  it "inherits fill and stroke from a group" do
    c = render_svg(svg.call(%(<g fill="none" stroke="blue" stroke-width="2"><rect width="5" height="5"/></g>)))
    c.should contain("0 0 1 RG")
    c.should contain("2 w")
    c.should contain("re\nS\n")
    c.should_not contain("rg")
  end

  it "inherits from style on the group and from the root svg" do
    c = render_svg(%(<svg width="10" height="10" fill="none" xmlns="http://www.w3.org/2000/svg"><g style="stroke:red"><rect width="5" height="5"/></g></svg>))
    c.should contain("1 0 0 RG")
    c.should contain("re\nS\n")
  end

  it "lets a child override an inherited value" do
    c = render_svg(svg.call(%(<g fill="none" stroke="blue"><rect width="5" height="5" fill="red" stroke="none"/></g>)))
    c.should contain("1 0 0 rg")
    c.should contain("re\nf\n")
  end

  it "splits style declarations on the first colon only" do
    c = render_svg(svg.call(%(<rect width="5" height="5" style="fill:red;font-family:a:b;stroke:blue"/>)))
    c.should contain("1 0 0 rg")
    c.should contain("0 0 1 RG")
  end
end
