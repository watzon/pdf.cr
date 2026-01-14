module PDF
  module Objects
    # Represents a PDF stream object.
    #
    # A stream consists of a dictionary followed by binary data.
    # The dictionary must contain at least a /Length entry specifying
    # the number of bytes in the stream data.
    #
    # Streams are used for page content, images, fonts, and other
    # binary data. They can be compressed using various filters.
    #
    # ```
    # stream = PDF::Objects::Stream.new
    # stream.data = "BT /F1 12 Tf 72 720 Td (Hello) Tj ET"
    # stream.to_pdf
    # # => "<</Length 38>>\nstream\nBT /F1 12 Tf 72 720 Td (Hello) Tj ET\nendstream"
    # ```
    #
    # Note: When used as an indirect object, the stream is typically
    # compressed with FlateDecode for smaller file size.
    class Stream < Base
      # The stream dictionary containing metadata
      getter dictionary : Dictionary

      # The raw stream data (before any encoding)
      property data : Bytes

      # The encoded stream data (after filters applied)
      # This is lazily computed and cached
      @encoded_data : Bytes?

      # Filters applied to this stream (in order)
      @filters : ::Array(Filters::Base)

      def initialize
        @dictionary = Dictionary.new
        @data = Bytes.empty
        @filters = ::Array(Filters::Base).new
        @encoded_data = nil
      end

      def initialize(@dictionary : Dictionary, @data : Bytes = Bytes.empty)
        @filters = ::Array(Filters::Base).new
        @encoded_data = nil
      end

      # Set data from a string
      def data=(content : String) : Bytes
        @encoded_data = nil # Invalidate cache
        @data = content.to_slice
      end

      # Set data from bytes
      def data=(bytes : Bytes) : Bytes
        @encoded_data = nil # Invalidate cache
        @data = bytes
      end

      # Add a filter to the stream
      def add_filter(filter : Filters::Base) : self
        @encoded_data = nil # Invalidate cache
        @filters << filter
        self
      end

      # Get the encoded data (applies filters)
      def encoded_data : Bytes
        @encoded_data ||= encode_data
      end

      # Set a dictionary entry
      def []=(key : Name, value : Base) : Base
        @dictionary[key] = value
      end

      def []=(key : String, value : Base) : Base
        @dictionary[key] = value
      end

      # Get a dictionary entry
      def [](key : Name) : Base
        @dictionary[key]
      end

      def [](key : String) : Base
        @dictionary[key]
      end

      def []?(key : Name) : Base?
        @dictionary[key]?
      end

      def []?(key : String) : Base?
        @dictionary[key]?
      end

      def to_pdf : ::String
        String.build do |io|
          to_pdf(io)
        end
      end

      def to_pdf(io : IO) : Nil
        # Encode data and update dictionary
        encoded = encoded_data

        # Update length
        @dictionary[Name::LENGTH] = Number.new(encoded.size)

        # Update filter entry if we have filters
        update_filter_entry

        # Write dictionary
        @dictionary.to_pdf(io)

        # Write stream content
        io << "\nstream\n"
        io.write(encoded)
        io << "\nendstream"
      end

      private def encode_data : Bytes
        result = @data
        @filters.each do |filter|
          result = filter.encode(result)
        end
        result
      end

      private def update_filter_entry
        return if @filters.empty?

        if @filters.size == 1
          @dictionary[Name::FILTER] = @filters.first.name
        else
          filter_array = Array.new
          @filters.each { |f| filter_array << f.name }
          @dictionary[Name::FILTER] = filter_array
        end
      end
    end
  end
end
