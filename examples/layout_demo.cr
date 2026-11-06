require "../src/pdf"

# Demonstrates the layout features: formatted text boxes, bounding and
# column boxes, tables, and SVG rendering.
#
# Run with: crystal run examples/layout_demo.cr

LOREM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod " \
        "tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, " \
        "quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."

SVG_LOGO = <<-SVG
  <svg xmlns="http://www.w3.org/2000/svg" width="120" height="60" viewBox="0 0 120 60">
    <rect x="0" y="0" width="120" height="60" fill="#EEEEEE" stroke="#333333"/>
    <g fill="none" stroke="blue" stroke-width="2">
      <path d="M10 50 A 20 20 0 0 1 50 50"/>
      <polyline points="60,50 75,10 90,50 105,10"/>
    </g>
    <circle cx="30" cy="20" r="8" fill="red"/>
    <rect x="70" y="35" width="20" height="10" fill="green" transform="rotate(-20 80 40)"/>
  </svg>
  SVG

doc = PDF::Document.new

doc.page do |page|
  page.font("Helvetica-Bold", size: 18)
  page.text("pdf.cr layout demo", at: {50, 750})

  # Formatted text with mixed styles, justified.
  page.formatted_text_box(
    [
      {text: "Formatted text: ", styles: [:bold]},
      {text: "mixed ", styles: [:italic]},
      {text: "styles", styles: [:underline], color: "CC0000"},
      {text: " and justified wrapping. " + LOREM, styles: [] of Symbol},
    ],
    at: {50, 730}, width: 250, height: 120, align: :justify,
  )

  # Bounding box with a visible outline.
  page.bounding_box(at: {320, 730}, width: 240, height: 120) do |box|
    box.text("Bounding box", font_size: 12)
    box.move_down(4)
    box.formatted_text([{text: LOREM, styles: [] of Symbol}])
    box.stroke_bounds
  end

  # Two columns of flowing text.
  page.column_box(at: {50, 590}, width: 510, height: 110, columns: 2, spacer: 20) do |col|
    col.formatted_text([{text: (LOREM + " ") * 3, styles: [] of Symbol}])
  end

  # SVG drawing.
  page.svg(SVG_LOGO, at: {50, 460}, width: 240.0)

  # Table with a header, colspan and striped rows.
  page.table(
    [
      ["Feature", "Issue", "Status"],
      ["Formatted text", "#1", "Integrated"],
      ["Bounding boxes", "#2", "Integrated"],
      ["Tables", "#3", "Integrated"],
      ["SVG", "#4", "Integrated"],
      [{content: "Spanning footer cell", colspan: 3, align: "center"}],
    ],
    at: {320, 460}, header: true, column_widths: [110.0, 50.0, 80.0],
    row_colors: ["F4F4F4", "FFFFFF"],
  )
end

doc.save("examples/layout_demo.pdf")
puts "Wrote examples/layout_demo.pdf"
