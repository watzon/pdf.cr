module PDF
  module Content
    # Constants for PDF graphics state operators and values.
    #
    # This module provides enums and constants for line caps, line joins,
    # blend modes, rendering intents, and other graphics state parameters.
    module GraphicsState
      # Line cap styles for stroking operations.
      #
      # - `butt`: Square end at the endpoint (default)
      # - `round`: Semicircular arc at endpoint
      # - `square`: Square end extended half line width beyond endpoint
      enum LineCap
        Butt   = 0
        Round  = 1
        Square = 2
      end

      # Line join styles for stroking operations.
      #
      # - `miter`: Sharp corner (default)
      # - `round`: Rounded corner
      # - `bevel`: Beveled corner
      enum LineJoin
        Miter = 0
        Round = 1
        Bevel = 2
      end

      # Blend modes for transparency compositing.
      #
      # Note: Requires PDF 1.4+ and ExtGState to use.
      enum BlendMode
        Normal
        Multiply
        Screen
        Overlay
        Darken
        Lighten
        ColorDodge
        ColorBurn
        HardLight
        SoftLight
        Difference
        Exclusion
        Hue
        Saturation
        Color
        Luminosity

        def to_pdf_name : String
          case self
          when Normal     then "Normal"
          when Multiply   then "Multiply"
          when Screen     then "Screen"
          when Overlay    then "Overlay"
          when Darken     then "Darken"
          when Lighten    then "Lighten"
          when ColorDodge then "ColorDodge"
          when ColorBurn  then "ColorBurn"
          when HardLight  then "HardLight"
          when SoftLight  then "SoftLight"
          when Difference then "Difference"
          when Exclusion  then "Exclusion"
          when Hue        then "Hue"
          when Saturation then "Saturation"
          when Color      then "Color"
          when Luminosity then "Luminosity"
          else                 raise "Unknown blend mode"
          end
        end
      end

      # Rendering intents for color reproduction.
      enum RenderingIntent
        AbsoluteColorimetric
        RelativeColorimetric
        Saturation
        Perceptual

        def to_pdf_name : String
          case self
          when AbsoluteColorimetric then "AbsoluteColorimetric"
          when RelativeColorimetric then "RelativeColorimetric"
          when Saturation           then "Saturation"
          when Perceptual           then "Perceptual"
          else                           raise "Unknown rendering intent"
          end
        end
      end

      # Text rendering modes.
      #
      # - `fill`: Fill text (default)
      # - `stroke`: Stroke text outlines
      # - `fill_stroke`: Fill and stroke text
      # - `invisible`: Invisible text (useful for OCR layers)
      # - `fill_clip`: Fill text and add to clipping path
      # - `stroke_clip`: Stroke text and add to clipping path
      # - `fill_stroke_clip`: Fill, stroke, and clip
      # - `clip`: Add text to clipping path only
      enum TextRenderMode
        Fill           = 0
        Stroke         = 1
        FillStroke     = 2
        Invisible      = 3
        FillClip       = 4
        StrokeClip     = 5
        FillStrokeClip = 6
        Clip           = 7
      end

      # Dash pattern for stroked paths.
      #
      # ```
      # # Solid line (default)
      # dash = DashPattern.new
      #
      # # Dashed line: 5 on, 3 off
      # dash = DashPattern.new([5, 3])
      #
      # # Dashed line with phase offset
      # dash = DashPattern.new([5, 3], phase: 2)
      # ```
      struct DashPattern
        getter array : Array(Float64)
        getter phase : Float64

        def initialize(@array : Array(Float64) = [] of Float64, @phase : Float64 = 0.0)
        end

        # Creates from integer array (convenience)
        def initialize(array : Array(Int32), phase : Number = 0)
          @array = array.map(&.to_f)
          @phase = phase.to_f
        end

        # Returns true if this is a solid line (no dashing)
        def solid? : Bool
          @array.empty?
        end

        # Formats for PDF output: [dash1 dash2 ...] phase
        def to_pdf : String
          "[#{@array.join(" ")}] #{format_number(@phase)}"
        end

        private def format_number(value : Float64) : String
          if value == value.round
            value.to_i.to_s
          else
            "%.4f".%(value).rstrip('0').rstrip('.')
          end
        end
      end
    end
  end
end
