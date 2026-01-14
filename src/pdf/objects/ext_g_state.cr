module PDF
  module Objects
    # Represents a PDF Extended Graphics State (ExtGState) dictionary.
    #
    # Extended graphics states allow setting graphics state parameters
    # that cannot be set directly in a content stream, such as:
    # - Transparency (fill and stroke opacity)
    # - Blend modes
    # - Overprint settings
    # - Line width, cap, join as resources
    #
    # ## Usage
    #
    # ```
    # # Create an ExtGState for 50% transparency
    # gs = PDF::Objects::ExtGState.new
    # gs.fill_opacity = 0.5
    # gs.stroke_opacity = 0.5
    # gs.blend_mode = PDF::Content::GraphicsState::BlendMode::Multiply
    #
    # # Use in page:
    # page.set_graphics_state(gs)
    # ```
    class ExtGState < Base
      # Type is always ExtGState
      TYPE = Name.new("ExtGState")

      # Fill (non-stroking) opacity (CA/ca) - 0.0 to 1.0
      property fill_opacity : Float64?

      # Stroke opacity (CA) - 0.0 to 1.0
      property stroke_opacity : Float64?

      # Blend mode (BM)
      property blend_mode : Content::GraphicsState::BlendMode?

      # Soft mask (SMask) - Name or dictionary
      property soft_mask : Base?

      # Line width (LW)
      property line_width : Float64?

      # Line cap style (LC)
      property line_cap : Content::GraphicsState::LineCap?

      # Line join style (LJ)
      property line_join : Content::GraphicsState::LineJoin?

      # Miter limit (ML)
      property miter_limit : Float64?

      # Dash pattern (D)
      property dash_pattern : Content::GraphicsState::DashPattern?

      # Rendering intent (RI)
      property rendering_intent : Content::GraphicsState::RenderingIntent?

      # Overprint mode (OPM) - 0 or 1
      property overprint_mode : Int32?

      # Stroke overprint (OP)
      property stroke_overprint : Bool?

      # Fill overprint (op)
      property fill_overprint : Bool?

      # Alpha source flag (AIS)
      property alpha_is_shape : Bool?

      # Text knockout flag (TK)
      property text_knockout : Bool?

      def initialize
      end

      # Creates an ExtGState with common opacity settings.
      def self.with_opacity(fill : Float64? = nil, stroke : Float64? = nil) : ExtGState
        gs = new
        gs.fill_opacity = fill
        gs.stroke_opacity = stroke
        gs
      end

      # Creates an ExtGState with a blend mode.
      def self.with_blend_mode(mode : Content::GraphicsState::BlendMode) : ExtGState
        gs = new
        gs.blend_mode = mode
        gs
      end

      # Converts to a PDF dictionary.
      def to_dictionary : Dictionary
        dict = Dictionary.new
        dict["Type"] = TYPE

        # Opacity parameters
        if fill_alpha = @fill_opacity
          dict["ca"] = Number.new(fill_alpha)
        end

        if stroke_alpha = @stroke_opacity
          dict["CA"] = Number.new(stroke_alpha)
        end

        # Blend mode
        if bm = @blend_mode
          dict["BM"] = Name.new(bm.to_pdf_name)
        end

        # Soft mask
        if sm = @soft_mask
          dict["SMask"] = sm
        end

        # Line width
        if lw = @line_width
          dict["LW"] = Number.new(lw)
        end

        # Line cap
        if lc = @line_cap
          dict["LC"] = Number.new(lc.value)
        end

        # Line join
        if lj = @line_join
          dict["LJ"] = Number.new(lj.value)
        end

        # Miter limit
        if ml = @miter_limit
          dict["ML"] = Number.new(ml)
        end

        # Dash pattern
        if dp = @dash_pattern
          arr = Array.new
          dp.array.each { |v| arr << Number.new(v) }
          dict["D"] = Array.new([arr, Number.new(dp.phase)])
        end

        # Rendering intent
        if ri = @rendering_intent
          dict["RI"] = Name.new(ri.to_pdf_name)
        end

        # Overprint mode
        if opm = @overprint_mode
          dict["OPM"] = Number.new(opm)
        end

        # Stroke overprint
        if op = @stroke_overprint
          dict["OP"] = Boolean.new(op)
        end

        # Fill overprint
        if op = @fill_overprint
          dict["op"] = Boolean.new(op)
        end

        # Alpha is shape
        if ais = @alpha_is_shape
          dict["AIS"] = Boolean.new(ais)
        end

        # Text knockout
        if tk = @text_knockout
          dict["TK"] = Boolean.new(tk)
        end

        dict
      end

      def to_pdf : String
        to_dictionary.to_pdf
      end

      def to_pdf(io : IO) : Nil
        to_dictionary.to_pdf(io)
      end

      # Generates a unique key based on the state's properties.
      # Used for deduplication and resource naming.
      def hash_key : UInt64
        hash = 0_u64
        hash = hash &* 31 &+ (@fill_opacity.try(&.hash) || 0_u64)
        hash = hash &* 31 &+ (@stroke_opacity.try(&.hash) || 0_u64)
        hash = hash &* 31 &+ (@blend_mode.try(&.hash) || 0_u64)
        hash = hash &* 31 &+ (@line_width.try(&.hash) || 0_u64)
        hash = hash &* 31 &+ (@line_cap.try(&.hash) || 0_u64)
        hash = hash &* 31 &+ (@line_join.try(&.hash) || 0_u64)
        hash = hash &* 31 &+ (@miter_limit.try(&.hash) || 0_u64)
        hash
      end
    end
  end
end
