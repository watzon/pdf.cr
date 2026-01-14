require "compress/zlib"

module PDF
  module Filters
    # FlateDecode filter - zlib/deflate compression.
    #
    # This is the most common compression filter in PDF files.
    # It uses the zlib compression algorithm (deflate).
    #
    # ```
    # filter = PDF::Filters::Flate.new
    # compressed = filter.encode("Hello, World!".to_slice)
    # decompressed = filter.decode(compressed)
    # String.new(decompressed) # => "Hello, World!"
    # ```
    class Flate < Base
      # Compression level (1-9, or -1 for default)
      getter level : Int32

      # /FlateDecode name
      NAME = Objects::Name.new("FlateDecode")

      def initialize(@level : Int32 = Compress::Zlib::DEFAULT_COMPRESSION)
      end

      def name : Objects::Name
        NAME
      end

      def encode(data : Bytes) : Bytes
        return Bytes.empty if data.empty?

        io = IO::Memory.new
        Compress::Zlib::Writer.open(io, level: @level) do |zlib|
          zlib.write(data)
        end
        io.to_slice
      end

      def decode(data : Bytes) : Bytes
        return Bytes.empty if data.empty?

        io = IO::Memory.new(data)
        result = IO::Memory.new

        Compress::Zlib::Reader.open(io) do |zlib|
          IO.copy(zlib, result)
        end

        result.to_slice
      end
    end
  end
end
