module PDF
  module Images
    # JPEG image handler with DCT passthrough.
    #
    # JPEG images are embedded directly in PDFs using DCTDecode filter.
    # The raw JPEG data is passed through without re-encoding, which:
    # - Preserves original quality
    # - Avoids decompression/recompression artifacts
    # - Keeps file size optimal
    #
    # ## Usage
    #
    # ```
    # jpeg = PDF::Images::JPEG.load("photo.jpg")
    # jpeg.width      # => 800
    # jpeg.height     # => 600
    # jpeg.color_space # => /DeviceRGB
    # ```
    class JPEG < Base
      # Raw JPEG data
      getter data : Bytes

      # Image dimensions
      getter width : Int32
      getter height : Int32

      # Color components (1=grayscale, 3=RGB, 4=CMYK)
      getter components : Int32

      def initialize(@data : Bytes, @width : Int32, @height : Int32, @components : Int32)
      end

      # Load JPEG from file path
      def self.load(path : String) : JPEG
        data = File.read(path).to_slice
        parse(data)
      end

      # Load JPEG from IO
      def self.load(io : IO) : JPEG
        data = io.getb_to_end
        parse(data)
      end

      # Load JPEG from bytes
      def self.load(data : Bytes) : JPEG
        parse(data)
      end

      # Parse JPEG header to extract dimensions and color info
      private def self.parse(data : Bytes) : JPEG
        # Validate JPEG signature (SOI marker)
        unless data.size >= 2 && data[0] == 0xFF && data[1] == 0xD8
          raise ArgumentError.new("Invalid JPEG: missing SOI marker")
        end

        width = 0
        height = 0
        components = 3 # Default to RGB

        i = 2
        while i < data.size - 1
          # Find marker
          unless data[i] == 0xFF
            i += 1
            next
          end

          marker = data[i + 1]
          i += 2

          # Skip padding bytes (0xFF followed by 0xFF)
          next if marker == 0xFF

          # End of image
          break if marker == 0xD9

          # Start of scan - image data follows, stop parsing
          break if marker == 0xDA

          # Markers without length
          if marker == 0x00 || marker == 0x01 || (0xD0..0xD7).includes?(marker)
            next
          end

          # Read segment length
          break if i + 2 > data.size
          length = (data[i].to_i32 << 8) | data[i + 1].to_i32
          break if length < 2

          # SOF markers (Start of Frame) contain dimensions
          # SOF0 = 0xC0 (Baseline DCT)
          # SOF1 = 0xC1 (Extended sequential DCT)
          # SOF2 = 0xC2 (Progressive DCT)
          if (0xC0..0xCF).includes?(marker) && marker != 0xC4 && marker != 0xC8 && marker != 0xCC
            break if i + 9 > data.size

            # bits_per_component = data[i + 2] # Usually 8
            height = (data[i + 3].to_i32 << 8) | data[i + 4].to_i32
            width = (data[i + 5].to_i32 << 8) | data[i + 6].to_i32
            components = data[i + 7].to_i32

            break # Found what we need
          end

          # Skip to next marker
          i += length
        end

        if width == 0 || height == 0
          raise ArgumentError.new("Invalid JPEG: could not find image dimensions")
        end

        new(data, width, height, components)
      end

      def bits_per_component : Int32
        8
      end

      def color_space : Objects::Name
        case @components
        when 1
          Objects::Name.new("DeviceGray")
        when 4
          Objects::Name.new("DeviceCMYK")
        else
          Objects::Name.new("DeviceRGB")
        end
      end

      def has_alpha? : Bool
        false # JPEG doesn't support alpha
      end

      def soft_mask_stream : Objects::Stream?
        nil # JPEG doesn't have alpha
      end

      # Create the image stream with DCT passthrough
      def to_stream : Objects::Stream
        stream = Objects::Stream.new
        stream.data = @data

        # Set up XObject dictionary entries
        stream["Type"] = Objects::Name::XOBJECT
        stream["Subtype"] = Objects::Name.new("Image")
        stream["Width"] = Objects::Number.new(@width)
        stream["Height"] = Objects::Number.new(@height)
        stream["ColorSpace"] = color_space
        stream["BitsPerComponent"] = Objects::Number.new(bits_per_component)

        # DCTDecode - PDF readers decode JPEG natively
        stream.add_filter(Filters::DCT.new)

        stream
      end
    end
  end
end
