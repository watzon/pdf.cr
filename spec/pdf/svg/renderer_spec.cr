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
      parser.width.should be_close(144.0, 0.1) # 2 * 72
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
