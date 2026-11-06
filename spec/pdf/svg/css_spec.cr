require "../../spec_helper"
require "../../../src/pdf/svg/css"

private def parse_doc(body : String) : XML::Node
  XML.parse(%(<svg xmlns="http://www.w3.org/2000/svg">#{body}</svg>))
end

private def node_by_id(doc : XML::Node, id : String) : XML::Node
  doc.xpath_node("//*[@id='#{id}']") || raise "missing node #{id}"
end

private def sheet_for(css : String) : PDF::SVG::CSS::Stylesheet
  sheet = PDF::SVG::CSS::Stylesheet.new
  sheet.add(css)
  sheet
end

private def props(sheet : PDF::SVG::CSS::Stylesheet, node : XML::Node) : Array(String)
  sheet.declarations_for(node).map { |decl| "#{decl.property}:#{decl.value}" }
end

describe PDF::SVG::CSS do
  describe ".parse_declarations" do
    it "splits on the first colon only" do
      decls = PDF::SVG::CSS.parse_declarations("font-family: a:b")
      decls.size.should eq(1)
      decls[0].property.should eq("font-family")
      decls[0].value.should eq("a:b")
    end

    it "detects !important with and without a space" do
      decls = PDF::SVG::CSS.parse_declarations("fill: red !important; stroke:blue!important; opacity: 1")
      decls.map(&.important).should eq([true, true, false])
      decls.map(&.value).should eq(["red", "blue", "1"])
    end

    it "skips empty and malformed pieces" do
      decls = PDF::SVG::CSS.parse_declarations(";; nocolon; : v; p: ; fill: red;")
      decls.map(&.property).should eq(["fill"])
    end

    it "downcases and strips property names" do
      decls = PDF::SVG::CSS.parse_declarations("  FILL : Red ")
      decls[0].property.should eq("fill")
      decls[0].value.should eq("Red")
    end
  end

  describe "parsing" do
    it "strips comments, including multi-line ones" do
      sheet = sheet_for("/* a\n b */ rect /* x */ { fill: red; /* y */ }\n/* open")
      sheet.rule_count.should eq(1)
    end

    it "ignores HTML comment tokens" do
      sheet_for("<!-- rect { fill: red } -->").rule_count.should eq(1)
    end

    it "creates one rule per selector in a list" do
      sheet_for("rect, circle , .a { fill: red }").rule_count.should eq(3)
    end

    it "skips at-rules including nested blocks" do
      css = <<-CSS
        @charset "utf-8";
        @import url(x.css);
        @media print { .a { fill: red } rect { fill: blue } }
        @font-face { font-family: x; src: url(y) }
        circle { fill: green }
        CSS
      sheet = sheet_for(css)
      sheet.rule_count.should eq(1)
      doc = parse_doc(%(<circle id="x"/>))
      props(sheet, node_by_id(doc, "x")).should eq(["fill:green"])
    end

    it "never raises on malformed input" do
      ["{", "}", "rect {", "rect { fill", "@media {", "@", "a > { fill: red }", "{}}}", ",,{a:b}", "[ {a:b}"].each do |css|
        sheet_for(css)
      end
    end
  end

  describe "selectors" do
    doc = parse_doc(<<-XML)
      <g id="g1" class="a b">
        <g id="g2">
          <rect id="x" class="c d" data-k="v" data-w="one two"/>
        </g>
        <circle id="y"/>
      </g>
      XML
    x = node_by_id(doc, "x")
    y = node_by_id(doc, "y")

    it "matches type selectors case-sensitively" do
      props(sheet_for("rect { fill: red }"), x).size.should eq(1)
      props(sheet_for("RECT { fill: red }"), x).size.should eq(0)
      props(sheet_for("rect { fill: red }"), y).size.should eq(0)
    end

    it "matches the universal selector" do
      props(sheet_for("* { fill: red }"), x).size.should eq(1)
    end

    it "matches classes" do
      props(sheet_for(".c { fill: red }"), x).size.should eq(1)
      props(sheet_for(".c.d { fill: red }"), x).size.should eq(1)
      props(sheet_for(".c.z { fill: red }"), x).size.should eq(0)
      props(sheet_for("rect.d { fill: red }"), x).size.should eq(1)
    end

    it "matches ids" do
      props(sheet_for("#x { fill: red }"), x).size.should eq(1)
      props(sheet_for("#y { fill: red }"), x).size.should eq(0)
    end

    it "matches attribute selectors" do
      props(sheet_for("[data-k] { fill: red }"), x).size.should eq(1)
      props(sheet_for("[data-k=v] { fill: red }"), x).size.should eq(1)
      props(sheet_for(%([data-k="v"] { fill: red })), x).size.should eq(1)
      props(sheet_for("[data-k='v'] { fill: red }"), x).size.should eq(1)
      props(sheet_for("[data-k=w] { fill: red }"), x).size.should eq(0)
      props(sheet_for("[data-w~=two] { fill: red }"), x).size.should eq(1)
      props(sheet_for("[data-w~=tw] { fill: red }"), x).size.should eq(0)
      props(sheet_for("[nope] { fill: red }"), x).size.should eq(0)
    end

    it "supports the descendant combinator" do
      props(sheet_for("g rect { fill: red }"), x).size.should eq(1)
      props(sheet_for("svg rect { fill: red }"), x).size.should eq(1)
      props(sheet_for("circle rect { fill: red }"), x).size.should eq(0)
    end

    it "supports the child combinator with and without spaces" do
      props(sheet_for("g > rect { fill: red }"), x).size.should eq(1)
      props(sheet_for("g>rect { fill: red }"), x).size.should eq(1)
      props(sheet_for("#g1 > rect { fill: red }"), x).size.should eq(0)
      props(sheet_for("#g1 > #g2 > rect { fill: red }"), x).size.should eq(1)
    end

    it "backtracks for descendant combinators" do
      sheet = sheet_for("g.a rect { fill: red }")
      props(sheet, x).size.should eq(1)
      props(sheet_for("g.a > rect { fill: red }"), x).size.should eq(0)
    end

    it "ignores unsupported selectors without breaking the list" do
      sheet = sheet_for("rect:hover, rect::before, rect:first-child, a + b, a ~ b, svg|rect, .c { fill: red }")
      sheet.rule_count.should eq(1)
      props(sheet, x).should eq(["fill:red"])
    end
  end

  describe ".specificity" do
    it "counts ids, classes with attributes, and types" do
      PDF::SVG::CSS.specificity("rect").should eq({0, 0, 1})
      PDF::SVG::CSS.specificity("*").should eq({0, 0, 0})
      PDF::SVG::CSS.specificity(".a.b").should eq({0, 2, 0})
      PDF::SVG::CSS.specificity("#x").should eq({1, 0, 0})
      PDF::SVG::CSS.specificity("g.a > rect[fill]").should eq({0, 2, 2})
      PDF::SVG::CSS.specificity("#a rect.b").should eq({1, 1, 1})
    end

    it "returns nil for unsupported selectors" do
      PDF::SVG::CSS.specificity("a:hover").should be_nil
      PDF::SVG::CSS.specificity("a + b").should be_nil
      PDF::SVG::CSS.specificity("").should be_nil
      PDF::SVG::CSS.specificity("a >").should be_nil
    end
  end

  describe PDF::SVG::CSS::Stylesheet do
    doc = parse_doc(%(<rect id="x"/>))
    x = node_by_id(doc, "x")

    it "orders by specificity before source order" do
      sheet = sheet_for("#x { fill: blue } rect { fill: red }")
      props(sheet, x).should eq(["fill:red", "fill:blue"])
    end

    it "orders equal specificity by source order across add calls" do
      sheet = PDF::SVG::CSS::Stylesheet.new
      sheet.add("rect { fill: red }")
      sheet.add("rect { fill: green }")
      props(sheet, x).should eq(["fill:red", "fill:green"])
    end

    it "keeps the important flag" do
      sheet = sheet_for("rect { fill: red !important }")
      sheet.declarations_for(x)[0].important.should be_true
    end
  end
end
