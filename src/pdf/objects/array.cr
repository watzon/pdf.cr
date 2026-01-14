module PDF
  module Objects
    # Represents a PDF array object.
    #
    # PDF arrays are one-dimensional collections of objects enclosed
    # in square brackets. Array elements can be any PDF object type,
    # including other arrays (for multi-dimensional data).
    #
    # ```
    # arr = PDF::Objects::Array.new
    # arr << PDF::Objects::Number.new(1)
    # arr << PDF::Objects::Number.new(2)
    # arr << PDF::Objects::Number.new(3)
    # arr.to_pdf # => "[1 2 3]"
    #
    # # Or using the convenience initializer
    # arr = PDF::Objects::Array.new([1, 2, 3])
    # arr.to_pdf # => "[1 2 3]"
    # ```
    class Array < Base
      include Indexable(Base)

      @elements : ::Array(Base)

      def initialize
        @elements = ::Array(Base).new
      end

      def initialize(elements : ::Array(Base))
        @elements = elements.dup
      end

      # Convenience initializer for integer arrays
      def initialize(numbers : ::Array(Int32))
        @elements = numbers.map { |n| Number.new(n).as(Base) }
      end

      # Convenience initializer for float arrays
      def initialize(numbers : ::Array(Float64))
        @elements = numbers.map { |n| Number.new(n).as(Base) }
      end

      def to_pdf : ::String
        ::String.build do |io|
          to_pdf(io)
        end
      end

      def to_pdf(io : IO) : Nil
        io << '['
        @elements.each_with_index do |element, index|
          io << ' ' if index > 0
          element.to_pdf(io)
        end
        io << ']'
      end

      # Indexable implementation
      def size : Int32
        @elements.size
      end

      def unsafe_fetch(index : Int) : Base
        @elements.unsafe_fetch(index)
      end

      # Array mutation methods
      def <<(element : Base) : self
        @elements << element
        self
      end

      def push(element : Base) : self
        @elements << element
        self
      end

      def []=(index : Int, value : Base) : Base
        @elements[index] = value
      end

      def clear : self
        @elements.clear
        self
      end

      def empty? : Bool
        @elements.empty?
      end

      def_equals_and_hash @elements
    end
  end
end
