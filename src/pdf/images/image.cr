module PDF
  module Images
    # Unified image loader that auto-detects format.
    #
    # This module provides convenience methods to load images from
    # various sources and automatically detect whether they are
    # JPEG or PNG format.
    #
    # ## Usage
    #
    # ```
    # # Auto-detect format from file extension
    # image = PDF::Images::Image.load("photo.jpg")
    # image = PDF::Images::Image.load("logo.png")
    #
    # # Load from bytes (auto-detects by magic bytes)
    # image = PDF::Images::Image.load(bytes)
    #
    # # Load from IO (must specify format or use magic bytes)
    # image = PDF::Images::Image.load(io)
    # ```
    module Image
      # JPEG magic bytes: FF D8
      JPEG_MAGIC = Bytes[0xFF, 0xD8]

      # PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
      PNG_MAGIC = Bytes[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

      # Load image from file path (auto-detects format)
      def self.load(path : String) : Base
        extension = File.extname(path).downcase

        case extension
        when ".jpg", ".jpeg"
          JPEG.load(path)
        when ".png"
          PNG.load(path)
        else
          # Try to detect from file contents
          data = File.read(path).to_slice
          load(data)
        end
      end

      # Load image from bytes (auto-detects format by magic bytes)
      def self.load(data : Bytes) : Base
        if jpeg?(data)
          JPEG.load(data)
        elsif png?(data)
          PNG.load(data)
        else
          raise ArgumentError.new("Unknown image format: not a valid JPEG or PNG")
        end
      end

      # Load image from IO (reads all bytes and auto-detects)
      def self.load(io : IO) : Base
        data = io.getb_to_end
        load(data)
      end

      # Check if data starts with JPEG magic bytes
      def self.jpeg?(data : Bytes) : Bool
        return false if data.size < 2
        data[0] == JPEG_MAGIC[0] && data[1] == JPEG_MAGIC[1]
      end

      # Check if data starts with PNG magic bytes
      def self.png?(data : Bytes) : Bool
        return false if data.size < 8
        (0...8).all? { |i| data[i] == PNG_MAGIC[i] }
      end
    end
  end
end
