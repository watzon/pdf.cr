require "stumpy_png"

module PDF
  module Images
    # PNG image handler with alpha channel support.
    #
    # PNG images are decoded using stumpy_png and re-encoded with
    # FlateDecode for PDF embedding. Alpha channels are extracted
    # as separate soft mask images for transparency support.
    #
    # ## Usage
    #
    # ```
    # png = PDF::Images::PNG.load("logo.png")
    # png.width      # => 200
    # png.height     # => 100
    # png.has_alpha? # => true
    # ```
    class PNG < Base
      # Decoded RGB pixel data (no alpha)
      getter rgb_data : Bytes

      # Alpha channel data (if present)
      getter alpha_data : Bytes?

      # Image dimensions
      getter width : Int32
      getter height : Int32

      # Whether this PNG has meaningful transparency
      getter has_alpha : Bool

      def initialize(@rgb_data : Bytes, @alpha_data : Bytes?, @width : Int32, @height : Int32, @has_alpha : Bool)
      end

      # Load PNG from file path
      def self.load(path : String) : PNG
        canvas = StumpyPNG.read(path)
        from_canvas(canvas)
      end

      # Load PNG from IO
      def self.load(io : IO) : PNG
        canvas = StumpyPNG.read(io)
        from_canvas(canvas)
      end

      # Load PNG from bytes
      def self.load(data : Bytes) : PNG
        io = IO::Memory.new(data)
        canvas = StumpyPNG.read(io)
        from_canvas(canvas)
      end

      # Convert stumpy_png Canvas to PNG image data
      private def self.from_canvas(canvas : StumpyCore::Canvas) : PNG
        width = canvas.width
        height = canvas.height
        pixel_count = width * height

        # Pre-allocate byte arrays
        rgb_data = Bytes.new(pixel_count * 3)
        alpha_data = Bytes.new(pixel_count)

        has_meaningful_alpha = false
        rgb_offset = 0
        alpha_offset = 0

        # Extract RGB and alpha data from canvas
        # StumpyCore uses 16-bit color components, convert to 8-bit
        canvas.each_row do |row|
          row.each do |pixel|
            # Convert 16-bit to 8-bit by taking high byte
            rgb_data[rgb_offset] = (pixel.r >> 8).to_u8
            rgb_data[rgb_offset + 1] = (pixel.g >> 8).to_u8
            rgb_data[rgb_offset + 2] = (pixel.b >> 8).to_u8
            rgb_offset += 3

            alpha = (pixel.a >> 8).to_u8
            alpha_data[alpha_offset] = alpha
            alpha_offset += 1

            # Check if we have any non-opaque pixels
            has_meaningful_alpha = true if alpha < 255
          end
        end

        # Only keep alpha data if there's actual transparency
        final_alpha = has_meaningful_alpha ? alpha_data : nil

        new(rgb_data, final_alpha, width, height, has_meaningful_alpha)
      end

      def bits_per_component : Int32
        8
      end

      def color_space : Objects::Name
        Objects::Name.new("DeviceRGB")
      end

      def has_alpha? : Bool
        @has_alpha
      end

      # Create the main image stream (RGB data only)
      def to_stream : Objects::Stream
        stream = Objects::Stream.new
        stream.data = @rgb_data

        # Set up XObject dictionary entries
        stream["Type"] = Objects::Name::XOBJECT
        stream["Subtype"] = Objects::Name.new("Image")
        stream["Width"] = Objects::Number.new(@width)
        stream["Height"] = Objects::Number.new(@height)
        stream["ColorSpace"] = color_space
        stream["BitsPerComponent"] = Objects::Number.new(bits_per_component)

        # Note: SMask reference will be added by the caller if has_alpha?
        # since we need the indirect object reference

        # Compress with Flate
        stream.add_filter(Filters::Flate.new)

        stream
      end

      # Create the soft mask stream for transparency
      def soft_mask_stream : Objects::Stream?
        return nil unless @has_alpha

        alpha = @alpha_data
        return nil unless alpha

        stream = Objects::Stream.new
        stream.data = alpha

        # Soft mask is a grayscale image
        stream["Type"] = Objects::Name::XOBJECT
        stream["Subtype"] = Objects::Name.new("Image")
        stream["Width"] = Objects::Number.new(@width)
        stream["Height"] = Objects::Number.new(@height)
        stream["ColorSpace"] = Objects::Name.new("DeviceGray")
        stream["BitsPerComponent"] = Objects::Number.new(8)

        # Compress with Flate
        stream.add_filter(Filters::Flate.new)

        stream
      end
    end
  end
end
