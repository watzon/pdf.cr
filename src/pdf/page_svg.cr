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
      # SVG text selects its own fonts; the caller's font stays current.
      font, font_size, truetype_font = @current_font, @current_font_size, @current_truetype_font
      begin
        draw_svg(svg_data, at, width, height)
      ensure
        @current_font, @current_font_size, @current_truetype_font = font, font_size, truetype_font
      end
    end

    private def draw_svg(svg_data : String, at : Tuple(Number, Number), width : Float64?, height : Float64?) : SVG::Renderer
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
