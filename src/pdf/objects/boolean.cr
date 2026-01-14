module PDF
  module Objects
    # Represents a PDF boolean object.
    #
    # PDF booleans are the keywords `true` and `false`.
    #
    # ```
    # bool = PDF::Objects::Boolean.new(true)
    # bool.to_pdf # => "true"
    # ```
    class Boolean < Base
      getter value : Bool

      def initialize(@value : Bool)
      end

      def to_pdf : ::String
        @value ? "true" : "false"
      end

      # Allow boolean coercion
      def to_b : Bool
        @value
      end

      def_equals_and_hash @value
    end
  end
end
