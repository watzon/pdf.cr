module PDF
  module Objects
    # Represents a PDF null object.
    #
    # The null object has a type and value that are unequal to those
    # of any other object. There is only one object of type null,
    # denoted by the keyword `null`.
    #
    # ```
    # null = PDF::Objects::Null.new
    # null.to_pdf # => "null"
    # ```
    class Null < Base
      # Singleton instance
      INSTANCE = new

      def to_pdf : ::String
        "null"
      end

      def_equals_and_hash

      # Convenience method to get the singleton
      def self.instance : Null
        INSTANCE
      end
    end
  end
end
