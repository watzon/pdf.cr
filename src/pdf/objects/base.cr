module PDF
  module Objects
    # Abstract base class for all PDF objects.
    #
    # PDF has 8 basic object types:
    # - Boolean (true/false)
    # - Numeric (integer and real)
    # - String (literal and hexadecimal)
    # - Name (/Identifier)
    # - Array ([obj1 obj2 ...])
    # - Dictionary (<< /Key value >>)
    # - Stream (dictionary + binary data)
    # - Null (null)
    #
    # Objects can be either direct (inline) or indirect (referenced).
    # Indirect objects are wrapped in `N M obj ... endobj` syntax
    # and referenced using `N M R`.
    abstract class Base
      # Serializes this object to PDF syntax.
      #
      # Returns the PDF representation as a string.
      abstract def to_pdf : ::String

      # Serializes this object to an IO.
      #
      # By default, this writes the result of `#to_pdf` to the IO.
      # Subclasses may override for more efficient streaming.
      def to_pdf(io : IO) : Nil
        io << to_pdf
      end

      # Returns the byte size of the PDF representation.
      def pdf_byte_size : Int32
        to_pdf.bytesize
      end
    end
  end
end
