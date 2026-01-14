module PDF
  module Objects
    # Represents a PDF indirect object reference.
    #
    # An indirect reference consists of an object number, a generation
    # number, and the keyword `R`. It refers to an indirect object
    # defined elsewhere in the PDF file.
    #
    # ```
    # ref = PDF::Objects::Reference.new(5, 0)
    # ref.to_pdf # => "5 0 R"
    # ```
    #
    # Object numbers are positive integers. Generation numbers start
    # at 0 and are incremented when an object is deleted and reused.
    class Reference < Base
      getter object_number : Int32
      getter generation : Int32

      def initialize(@object_number : Int32, @generation : Int32 = 0)
        raise ArgumentError.new("Object number must be positive") if @object_number < 1
        raise ArgumentError.new("Generation must be non-negative") if @generation < 0
      end

      def to_pdf : ::String
        "#{@object_number} #{@generation} R"
      end

      def_equals_and_hash @object_number, @generation
    end
  end
end
