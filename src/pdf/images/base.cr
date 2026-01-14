module PDF
  module Images
    # Abstract base class for image handlers.
    #
    # Images are embedded in PDFs as XObject resources with /Subtype /Image.
    # Different image formats (JPEG, PNG) require different handling:
    # - JPEG: DCT passthrough (raw bytes embedded directly)
    # - PNG: Decoded to RGB/RGBA and re-encoded with FlateDecode
    abstract class Base
      # Image dimensions
      abstract def width : Int32
      abstract def height : Int32

      # Bits per color component (typically 8)
      abstract def bits_per_component : Int32

      # PDF color space name (/DeviceRGB, /DeviceGray, /DeviceCMYK)
      abstract def color_space : Objects::Name

      # Whether this image has transparency (alpha channel)
      abstract def has_alpha? : Bool

      # Returns the encoded image data stream for embedding
      abstract def to_stream : Objects::Stream

      # Returns the soft mask stream for transparency (if applicable)
      abstract def soft_mask_stream : Objects::Stream?

      # Build the Image XObject dictionary
      def to_xobject : Objects::Dictionary
        dict = Objects::Dictionary.new
        dict["Type"] = Objects::Name::XOBJECT
        dict["Subtype"] = Objects::Name.new("Image")
        dict["Width"] = Objects::Number.new(width)
        dict["Height"] = Objects::Number.new(height)
        dict["ColorSpace"] = color_space
        dict["BitsPerComponent"] = Objects::Number.new(bits_per_component)
        dict
      end
    end
  end
end
