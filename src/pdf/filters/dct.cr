module PDF
  module Filters
    # DCTDecode filter - JPEG/DCT passthrough.
    #
    # This filter is used for JPEG image data. Unlike other filters,
    # we don't actually decode/encode JPEG data - we pass it through
    # as-is since PDF readers handle DCT decoding natively.
    #
    # ```
    # filter = PDF::Filters::DCT.new
    # # JPEG data passes through unchanged
    # output = filter.encode(jpeg_bytes)
    # ```
    class DCT < Base
      # /DCTDecode name
      NAME = Objects::Name.new("DCTDecode")

      def name : Objects::Name
        NAME
      end

      # JPEG data is passed through unchanged - PDF readers decode it
      def encode(data : Bytes) : Bytes
        data
      end

      # JPEG decoding - not implemented (use stumpy_jpeg if needed)
      def decode(data : Bytes) : Bytes
        raise "DCT decoding not implemented - use stumpy_jpeg for JPEG parsing"
      end
    end
  end
end
