module PDF
  module SVG
    # Maps a CSS `font-family` list plus `font-weight` and `font-style` to
    # one of the standard 14 PDF fonts.
    #
    # The first family in the list that has a known mapping wins. Unknown
    # families fall back to Helvetica. Symbol and ZapfDingbats have no
    # bold or italic variants.
    module FontMap
      # Family name (lowercase) to standard font base name.
      FAMILIES = {
        "serif"            => "Times",
        "times"            => "Times",
        "times new roman"  => "Times",
        "times-roman"      => "Times",
        "georgia"          => "Times",
        "cambria"          => "Times",
        "garamond"         => "Times",
        "sans-serif"       => "Helvetica",
        "helvetica"        => "Helvetica",
        "arial"            => "Helvetica",
        "verdana"          => "Helvetica",
        "tahoma"           => "Helvetica",
        "trebuchet ms"     => "Helvetica",
        "segoe ui"         => "Helvetica",
        "dejavu sans"      => "Helvetica",
        "liberation sans"  => "Helvetica",
        "open sans"        => "Helvetica",
        "roboto"           => "Helvetica",
        "system-ui"        => "Helvetica",
        "monospace"        => "Courier",
        "courier"          => "Courier",
        "courier new"      => "Courier",
        "consolas"         => "Courier",
        "menlo"            => "Courier",
        "monaco"           => "Courier",
        "dejavu sans mono" => "Courier",
        "liberation mono"  => "Courier",
        "source code pro"  => "Courier",
        "symbol"           => "Symbol",
        "zapfdingbats"     => "ZapfDingbats",
        "zapf dingbats"    => "ZapfDingbats",
      }

      # Standard font names per base family: {regular, bold, italic, bold italic}.
      VARIANTS = {
        "Helvetica" => {"Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique"},
        "Times"     => {"Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic"},
        "Courier"   => {"Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique"},
      }

      # Returns the standard PDF font name for the given CSS values.
      def self.resolve(family : String?, weight : String? = nil, style : String? = nil) : String
        base = base_family(family)
        variants = VARIANTS[base]?
        return base unless variants

        index = (bold?(weight) ? 1 : 0) + (italic?(style) ? 2 : 0)
        variants[index]
      end

      private def self.base_family(family : String?) : String
        return "Helvetica" unless family

        family.split(',').each do |name|
          key = name.strip.strip('"').strip('\'').strip.downcase
          if base = FAMILIES[key]?
            return base
          end
        end
        "Helvetica"
      end

      private def self.bold?(weight : String?) : Bool
        return false unless weight
        weight = weight.strip.downcase
        return true if weight == "bold" || weight == "bolder"
        (weight.to_i? || 400) >= 600
      end

      private def self.italic?(style : String?) : Bool
        return false unless style
        style = style.strip.downcase
        style == "italic" || style == "oblique"
      end
    end
  end
end
