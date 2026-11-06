module PDF
  class Page
    # Renders an SVG string onto the page at the specified position.
    #
    # ```
    # svg_data = File.read("image.svg")
    # page.svg(svg_data, at: {50, 700}, width: 200)
    # ```
    def svg(
      svg_data : String,
      *,
      at : Tuple(Number, Number) = {0, 0},
      width : Float64? = nil,
      height : Float64? = nil,
    ) : SVG::Renderer
      parser = SVG::Parser.new(svg_data)
      renderer = SVG::Renderer.new(
        self,
        parser,
        x: at[0].to_f,
        y: at[1].to_f,
        width: width,
        height: height,
      )
      renderer.draw
      renderer
    end
  end
end
