module PDF
  module Filters
    # Abstract base class for PDF stream filters.
    #
    # Filters encode/decode stream data for compression,
    # encryption, or ASCII encoding.
    abstract class Base
      # Returns the PDF name for this filter (e.g., /FlateDecode)
      abstract def name : Objects::Name

      # Encodes data using this filter
      abstract def encode(data : Bytes) : Bytes

      # Decodes data using this filter
      abstract def decode(data : Bytes) : Bytes
    end
  end
end
