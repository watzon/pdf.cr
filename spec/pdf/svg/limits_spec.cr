require "../../spec_helper"

# Regression specs for bounded work on hostile input (CSS selectors, use
# fan-out and cycles) and for page state that leaks into or out of
# `Page#svg`.

private def limits_svg(body : String) : String
  %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">#{body}</svg>)
end

# Renders the SVG on a fresh page and returns {content stream, renderer}.
private def limits_render(svg : String, &setup : PDF::Page ->) : Tuple(String, PDF::SVG::Renderer)
  page = PDF::Document.new.page { }
  setup.call(page)
  renderer = page.svg(svg)
  {page.content_string, renderer}
end

private def limits_render(svg : String) : Tuple(String, PDF::SVG::Renderer)
  limits_render(svg) { }
end

private def limits_elapsed(&) : Time::Span
  start = Time.instant
  yield
  Time.instant - start
end

describe "SVG limits" do
  describe "CSS selector matching" do
    it "matches a long descendant selector on a deep tree in bounded time" do
      depth = 60
      nested = "<g>" * depth + %(<rect width="1" height="1"/>) + "</g>" * depth
      # The leading "x" never matches, so a naive matcher tries every way
      # to map the 13 "g rect" compounds onto 60 ancestors.
      selector = "x " + (["g"] * 12).join(" ") + " rect"
      svg = limits_svg(%(<style>#{selector} { fill: red }</style>#{nested}))

      content = ""
      elapsed = limits_elapsed { content = limits_render(svg)[0] }

      elapsed.should be < 2.seconds
      content.should contain("0 0 0 rg") # rule does not match: default black
    end

    it "still finds a match that needs backtracking past the nearest ancestor" do
      # The nearest g ancestor of the rect is inside <a>, not directly in
      # the x-class group; only the outer g satisfies `.x > g`.
      svg = limits_svg(<<-SVG)
        <style>.x > g rect { fill: #00ff00 }</style>
        <g class="x"><g><a><g><rect width="1" height="1"/></g></a></g></g>
        SVG

      limits_render(svg)[0].should contain("0 1 0 rg")
    end
  end

  describe "use references" do
    it "stops exponential use fan-out at the element budget with a warning" do
      defs = String.build do |io|
        io << %(<rect id="a0" width="1" height="1"/>)
        (1..20).each { |i| io << %(<g id="a#{i}"><use href="#a#{i - 1}"/><use href="#a#{i - 1}"/></g>) }
      end
      svg = limits_svg(%(<defs>#{defs}</defs><use href="#a20"/>))

      start = Time.instant
      content, renderer = limits_render(svg)
      elapsed = Time.instant - start

      elapsed.should be < 10.seconds
      content.scan(/ re\n/).size.should be <= PDF::SVG::Renderer::MAX_USE_ELEMENTS + 1
      renderer.warnings.any?(&.includes?("Too many elements drawn through use")).should be_true
    end

    it "bounds use fan-out inside clip paths" do
      svg = limits_svg(<<-SVG)
        <clipPath id="c"><use href="#c"/><use href="#c"/><use href="#c"/><rect width="10" height="10"/></clipPath>
        <rect width="50" height="50" clip-path="url(#c)"/>
        SVG

      content = ""
      elapsed = limits_elapsed { content = limits_render(svg)[0] }

      elapsed.should be < 2.seconds
      content.should contain("0 0 10 10 re\nW\nn")
    end

    it "draws nothing for a use that references its own ancestor" do
      svg = limits_svg(%(<g id="a"><rect width="10" height="10"/><use href="#a" x="20"/></g>))

      content = limits_render(svg)[0]

      content.scan("0 0 10 10 re").size.should eq(1)
      content.should_not contain("1 0 0 1 20 0 cm")
    end
  end

  describe "page state" do
    it "uses SVG stroke defaults whatever line state the page had" do
      svg = limits_svg(%(<polyline points="0,0 50,5 0,10" stroke="black" fill="none"/>))

      content = limits_render(svg) do |page|
        page.line_width(7)
        page.miter_limit(10)
        page.dash([3, 2])
      end[0]

      svg_part = content[content.index!("1 0 0 -1")..]
      svg_part.should contain("1 w\n0 J\n0 j\n4 M\n[] 0 d\n")
    end

    it "keeps the caller's font current after SVG text" do
      svg = limits_svg(%(<text x="10" y="20" font-family="serif">Hi</text>))
      content = ""
      PDF::Document.new.page do |page|
        page.font("Courier", size: 9)
        page.svg(svg)
        page.text("after", at: {10, 10})
        content = page.content_string
      end

      last_text = content[content.rindex!("BT")..]
      last_text.should contain("/F1 9 Tf")
      last_text.should contain("(after) Tj")
    end
  end
end
