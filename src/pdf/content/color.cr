module PDF
  module Content
    # Color management for PDF content streams.
    #
    # Provides color utilities and named color support for PDF generation.
    # Supports DeviceGray, DeviceRGB, and DeviceCMYK color spaces.
    #
    # ## Named Colors
    #
    # ```
    # color = PDF::Content::Color.named(:red)
    # # => {1.0, 0.0, 0.0}
    #
    # color = PDF::Content::Color.from_hex("#FF5500")
    # # => {1.0, 0.333, 0.0}
    # ```
    module Color
      # Named RGB colors (values 0.0 to 1.0)
      NAMED_COLORS = {
        black:   {0.0, 0.0, 0.0},
        white:   {1.0, 1.0, 1.0},
        red:     {1.0, 0.0, 0.0},
        green:   {0.0, 1.0, 0.0},
        blue:    {0.0, 0.0, 1.0},
        yellow:  {1.0, 1.0, 0.0},
        cyan:    {0.0, 1.0, 1.0},
        magenta: {1.0, 0.0, 1.0},
        orange:  {1.0, 0.647, 0.0},
        purple:  {0.5, 0.0, 0.5},
        pink:    {1.0, 0.753, 0.796},
        brown:   {0.647, 0.165, 0.165},
        gray:    {0.5, 0.5, 0.5},
        grey:    {0.5, 0.5, 0.5},
        silver:  {0.753, 0.753, 0.753},
        navy:    {0.0, 0.0, 0.502},
        teal:    {0.0, 0.502, 0.502},
        olive:   {0.502, 0.502, 0.0},
        maroon:  {0.502, 0.0, 0.0},
        lime:    {0.0, 1.0, 0.0},
        aqua:    {0.0, 1.0, 1.0},
        fuchsia: {1.0, 0.0, 1.0},
      }

      # Returns RGB components for a named color.
      #
      # ```
      # r, g, b = PDF::Content::Color.named(:red)
      # # => {1.0, 0.0, 0.0}
      # ```
      def self.named(name : Symbol) : Tuple(Float64, Float64, Float64)
        NAMED_COLORS[name]? || raise ArgumentError.new("Unknown color: #{name}")
      end

      # Parses a hex color string to RGB components.
      #
      # Supports formats: "#RGB", "#RRGGBB", "RGB", "RRGGBB"
      #
      # ```
      # PDF::Content::Color.from_hex("#FF0000") # => {1.0, 0.0, 0.0}
      # PDF::Content::Color.from_hex("00FF00")  # => {0.0, 1.0, 0.0}
      # PDF::Content::Color.from_hex("#F00")    # => {1.0, 0.0, 0.0}
      # ```
      def self.from_hex(hex : String) : Tuple(Float64, Float64, Float64)
        # Remove leading # if present
        hex = hex.lstrip('#')

        r, g, b = case hex.size
                  when 3
                    # Short form: #RGB -> #RRGGBB
                    {
                      hex[0].to_s.to_i(16) * 17,
                      hex[1].to_s.to_i(16) * 17,
                      hex[2].to_s.to_i(16) * 17,
                    }
                  when 6
                    # Full form: #RRGGBB
                    {
                      hex[0, 2].to_i(16),
                      hex[2, 2].to_i(16),
                      hex[4, 2].to_i(16),
                    }
                  else
                    raise ArgumentError.new("Invalid hex color: #{hex}")
                  end

        {r / 255.0, g / 255.0, b / 255.0}
      end

      # Converts RGB color to grayscale using luminance formula.
      #
      # ```
      # gray = PDF::Content::Color.rgb_to_gray(1.0, 0.0, 0.0)
      # # => 0.2126
      # ```
      def self.rgb_to_gray(r : Float64, g : Float64, b : Float64) : Float64
        # ITU-R BT.709 coefficients for perceived luminance
        0.2126 * r + 0.7152 * g + 0.0722 * b
      end

      # Converts RGB color to CMYK.
      #
      # ```
      # c, m, y, k = PDF::Content::Color.rgb_to_cmyk(1.0, 0.0, 0.0)
      # # => {0.0, 1.0, 1.0, 0.0}
      # ```
      def self.rgb_to_cmyk(r : Float64, g : Float64, b : Float64) : Tuple(Float64, Float64, Float64, Float64)
        # Handle pure black
        if r == 0.0 && g == 0.0 && b == 0.0
          return {0.0, 0.0, 0.0, 1.0}
        end

        k = 1.0 - Math.max(r, Math.max(g, b))
        c = (1.0 - r - k) / (1.0 - k)
        m = (1.0 - g - k) / (1.0 - k)
        y = (1.0 - b - k) / (1.0 - k)

        {c, m, y, k}
      end

      # Converts CMYK color to RGB.
      #
      # ```
      # r, g, b = PDF::Content::Color.cmyk_to_rgb(0.0, 1.0, 1.0, 0.0)
      # # => {1.0, 0.0, 0.0}
      # ```
      def self.cmyk_to_rgb(c : Float64, m : Float64, y : Float64, k : Float64) : Tuple(Float64, Float64, Float64)
        r = (1.0 - c) * (1.0 - k)
        g = (1.0 - m) * (1.0 - k)
        b = (1.0 - y) * (1.0 - k)
        {r, g, b}
      end

      # Clamps a color value to the valid range [0.0, 1.0].
      def self.clamp(value : Float64) : Float64
        value.clamp(0.0, 1.0)
      end
    end
  end
end
