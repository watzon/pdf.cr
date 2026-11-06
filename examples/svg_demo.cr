require "../src/pdf"

# Renders one SVG per feature in a grid, each with a caption.
#
#   crystal run examples/svg_demo.cr -- [output.pdf]

SAMPLES = {
  "use + symbol viewBox" => <<-SVG,
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="160" height="120">
      <defs>
        <symbol id="star" viewBox="0 0 100 100">
          <polygon points="50,5 61,38 95,38 67,59 78,92 50,72 22,92 33,59 5,38 39,38"/>
        </symbol>
        <rect id="box" width="30" height="20" rx="4"/>
      </defs>
      <use xlink:href="#star" x="0" y="0" width="60" height="60" fill="gold" stroke="black"/>
      <use href="#star" x="70" y="10" width="40" height="40" fill="tomato"/>
      <use href="#box" x="10" y="80" fill="steelblue"/>
      <use href="#box" x="60" y="80" fill="seagreen" transform="rotate(10 75 90)"/>
    </svg>
    SVG
  "text, tspan, anchor, fonts" => <<-SVG,
    <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
      <line x1="80" y1="0" x2="80" y2="120" stroke="#ccc"/>
      <text x="80" y="20" text-anchor="start" font-size="12">start</text>
      <text x="80" y="38" text-anchor="middle" font-size="12">middle</text>
      <text x="80" y="56" text-anchor="end" font-size="12">end</text>
      <text x="10" y="80" font-family="Georgia, serif" font-size="13">Serif <tspan font-weight="bold" fill="crimson">bold</tspan>
        <tspan font-style="italic">italic</tspan></text>
      <text x="10" y="100" font-family="monospace" font-size="11">mono<tspan dy="-5" font-size="8">sup</tspan><tspan dy="5"> back</tspan></text>
      <text x="10 22 34 46" y="115" font-size="10" fill="navy">ABCD</text>
    </svg>
    SVG
  "CSS rules and classes" => <<-SVG,
    <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
      <style>
        rect { fill: gray; }
        .warn { fill: orange; stroke: black; stroke-width: 2 }
        #special { fill: purple; }
        g.row > rect.warn { fill: red }
        .forced { fill: green !important }
      </style>
      <rect x="5" y="5" width="40" height="40"/>
      <rect x="55" y="5" width="40" height="40" class="warn"/>
      <rect x="105" y="5" width="40" height="40" class="warn" id="special"/>
      <g class="row">
        <rect x="5" y="60" width="40" height="40" class="warn"/>
        <rect x="55" y="60" width="40" height="40" class="forced" style="fill: blue"/>
      </g>
    </svg>
    SVG
  "gradients with transparency" => <<-SVG,
    <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
      <defs>
        <linearGradient id="lin" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stop-color="blue"/>
          <stop offset="0.5" stop-color="white"/>
          <stop offset="1" stop-color="red"/>
        </linearGradient>
        <linearGradient id="fade" x2="0" y2="1">
          <stop offset="0" stop-color="green" stop-opacity="1"/>
          <stop offset="1" stop-color="green" stop-opacity="0"/>
        </linearGradient>
        <radialGradient id="rad" cx="50%" cy="50%" r="50%" fx="30%" fy="30%">
          <stop offset="0%" style="stop-color: yellow"/>
          <stop offset="100%" style="stop-color: darkorange"/>
        </radialGradient>
      </defs>
      <text x="5" y="70" font-size="30" fill="black">behind</text>
      <rect x="5" y="5" width="70" height="40" fill="url(#lin)" stroke="black"/>
      <rect x="5" y="50" width="70" height="65" fill="url(#fade)"/>
      <circle cx="120" cy="40" r="35" fill="url(#rad)"/>
      <rect x="90" y="85" width="60" height="25" fill="none" stroke="url(#lin)" stroke-width="6"/>
    </svg>
    SVG
  "clipPath" => <<-SVG,
    <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
      <defs>
        <clipPath id="c1"><circle cx="40" cy="60" r="35"/></clipPath>
        <clipPath id="c2" clipPathUnits="objectBoundingBox">
          <polygon points="0.5,0 1,1 0,1"/>
        </clipPath>
      </defs>
      <g clip-path="url(#c1)">
        <rect x="0" y="0" width="80" height="60" fill="teal"/>
        <rect x="0" y="60" width="80" height="60" fill="salmon"/>
      </g>
      <rect x="90" y="25" width="60" height="70" fill="indigo" clip-path="url(#c2)"/>
    </svg>
    SVG
  "opacity" => <<-SVG,
    <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
      <circle cx="50" cy="45" r="35" fill="red" opacity="0.5"/>
      <circle cx="80" cy="45" r="35" fill="lime" fill-opacity="0.5"/>
      <circle cx="65" cy="75" r="35" fill="blue" stroke="black" stroke-width="6" stroke-opacity="0.3" fill-opacity="0.5"/>
      <g opacity="0.4"><rect x="115" y="10" width="40" height="100" fill="black"/></g>
    </svg>
    SVG
  "rounded rects" => <<-SVG,
    <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
      <rect x="5" y="5" width="70" height="50" rx="10" fill="lightblue" stroke="navy"/>
      <rect x="85" y="5" width="70" height="50" rx="20" ry="8" fill="lightgreen" stroke="darkgreen"/>
      <rect x="5" y="65" width="70" height="50" ry="40" fill="pink" stroke="crimson"/>
      <rect x="85" y="65" width="70" height="50" rx="5%" fill="wheat" stroke="sienna"/>
    </svg>
    SVG
  "stroke dash, cap, join" => <<-SVG,
    <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
      <g stroke="black" stroke-width="6" fill="none">
        <line x1="10" y1="15" x2="150" y2="15" stroke-dasharray="10 5"/>
        <line x1="10" y1="35" x2="150" y2="35" stroke-dasharray="1,10" stroke-linecap="round"/>
        <line x1="10" y1="55" x2="150" y2="55" stroke-dasharray="15" stroke-dashoffset="7" stroke-linecap="square"/>
        <g stroke-linejoin="round" stroke="maroon">
          <polyline points="10,110 30,70 50,110"/>
          <polyline points="60,110 80,70 100,110" stroke-linejoin="bevel"/>
          <polyline points="110,110 130,70 150,110" stroke-linejoin="miter" stroke-width="3"/>
        </g>
      </g>
    </svg>
    SVG
  "nested svg viewports" => <<-SVG,
    <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
      <rect width="160" height="120" fill="none" stroke="#999"/>
      <svg x="10" y="10" width="60" height="40" viewBox="0 0 10 10">
        <rect width="10" height="10" fill="orange"/>
        <circle cx="5" cy="5" r="6" fill="purple"/>
      </svg>
      <svg x="90" y="10" width="60" height="100">
        <circle cx="30" cy="30" r="40" fill="seagreen"/>
      </svg>
      <svg x="10" y="60" width="60" height="50" viewBox="0 0 10 10" preserveAspectRatio="none">
        <circle cx="5" cy="5" r="5" fill="crimson"/>
      </svg>
    </svg>
    SVG
  "preserveAspectRatio" => <<-SVG,
    <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
      <defs>
        <symbol id="s" viewBox="0 0 20 10"><rect width="20" height="10" fill="gold"/><circle cx="10" cy="5" r="5" fill="navy"/></symbol>
        <symbol id="meet" viewBox="0 0 20 10" preserveAspectRatio="xMinYMax meet"><use href="#s"/></symbol>
        <symbol id="slice" viewBox="0 0 20 10" preserveAspectRatio="xMidYMid slice"><use href="#s"/></symbol>
        <symbol id="none" viewBox="0 0 20 10" preserveAspectRatio="none"><use href="#s"/></symbol>
      </defs>
      <rect x="5" y="5" width="45" height="110" fill="none" stroke="#999"/>
      <use href="#meet" x="5" y="5" width="45" height="110"/>
      <rect x="57" y="5" width="45" height="110" fill="none" stroke="#999"/>
      <use href="#slice" x="57" y="5" width="45" height="110"/>
      <rect x="110" y="5" width="45" height="110" fill="none" stroke="#999"/>
      <use href="#none" x="110" y="5" width="45" height="110"/>
    </svg>
    SVG
}

pdf = PDF::Document.new
pdf.title = "SVG Demo"

pdf.page do |page|
  page.font "Helvetica-Bold", size: 18
  page.text "SVG rendering", at: {40, 760}

  SAMPLES.each_with_index do |(caption, svg), index|
    column = index % 3
    row = index // 3
    x = 40 + column * 180
    y = 730 - row * 175
    page.font "Helvetica", size: 9
    page.fill_color(0, 0, 0)
    page.text caption, at: {x, y - 135}
    page.svg(svg, at: {x, y}, width: 160.0)
  end
end

output = ARGV[0]? || "svg_demo.pdf"
pdf.save(output)
puts "Wrote #{output}"
