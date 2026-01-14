module PDF
  module Objects
    # Represents a PDF indirect object.
    #
    # An indirect object is a labeled object that can be referenced
    # from elsewhere in the PDF. It consists of:
    # - Object number (positive integer)
    # - Generation number (non-negative integer)
    # - The object value
    #
    # ```
    # dict = PDF::Objects::Dictionary.new
    # dict["Type"] = PDF::Objects::Name::PAGE
    #
    # obj = PDF::Objects::Indirect.new(5, 0, dict)
    # obj.to_pdf
    # # => "5 0 obj\n<</Type /Page>>\nendobj"
    #
    # obj.reference.to_pdf
    # # => "5 0 R"
    # ```
    class Indirect < Base
      getter object_number : Int32
      getter generation : Int32
      getter value : Base

      def initialize(@object_number : Int32, @generation : Int32, @value : Base)
        raise ArgumentError.new("Object number must be positive") if @object_number < 1
        raise ArgumentError.new("Generation must be non-negative") if @generation < 0
      end

      # Creates an indirect object with generation 0
      def initialize(object_number : Int32, value : Base)
        initialize(object_number, 0, value)
      end

      def to_pdf : ::String
        String.build do |io|
          to_pdf(io)
        end
      end

      def to_pdf(io : IO) : Nil
        io << @object_number
        io << ' '
        io << @generation
        io << " obj\n"
        @value.to_pdf(io)
        io << "\nendobj"
      end

      # Returns a Reference to this indirect object
      def reference : Reference
        Reference.new(@object_number, @generation)
      end

      # Alias for reference
      def ref : Reference
        reference
      end

      def_equals_and_hash @object_number, @generation, @value
    end
  end
end
