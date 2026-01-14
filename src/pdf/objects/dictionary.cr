module PDF
  module Objects
    # Represents a PDF dictionary object.
    #
    # A PDF dictionary is an associative table of name-value pairs.
    # Keys must be Name objects; values can be any PDF object type.
    #
    # ```
    # dict = PDF::Objects::Dictionary.new
    # dict[PDF::Objects::Name::TYPE] = PDF::Objects::Name::PAGE
    # dict[PDF::Objects::Name.new("Count")] = PDF::Objects::Number.new(5)
    # dict.to_pdf # => "<</Type /Page /Count 5>>"
    # ```
    class Dictionary < Base
      @entries : Hash(Name, Base)

      def initialize
        @entries = Hash(Name, Base).new
      end

      def initialize(entries : Hash(Name, Base))
        @entries = entries.dup
      end

      def to_pdf : ::String
        ::String.build do |io|
          to_pdf(io)
        end
      end

      def to_pdf(io : IO) : Nil
        io << "<<"
        @entries.each do |key, value|
          io << key.to_pdf
          io << ' '
          value.to_pdf(io)
        end
        io << ">>"
      end

      # Get a value by Name
      def [](key : Name) : Base
        @entries[key]
      end

      # Get a value by Name, returning nil if not found
      def []?(key : Name) : Base?
        @entries[key]?
      end

      # Set a value by Name
      def []=(key : Name, value : Base) : Base
        @entries[key] = value
      end

      # Get a value by string key (convenience method)
      def [](key : ::String) : Base
        @entries[Name.new(key)]
      end

      # Get a value by string key, returning nil if not found
      def []?(key : ::String) : Base?
        @entries[Name.new(key)]?
      end

      # Set a value by string key (convenience method)
      def []=(key : ::String, value : Base) : Base
        @entries[Name.new(key)] = value
      end

      # Check if a key exists
      def has_key?(key : Name) : Bool
        @entries.has_key?(key)
      end

      # Check if a string key exists
      def has_key?(key : ::String) : Bool
        @entries.has_key?(Name.new(key))
      end

      # Delete a key
      def delete(key : Name) : Base?
        @entries.delete(key)
      end

      # Delete a string key
      def delete(key : ::String) : Base?
        @entries.delete(Name.new(key))
      end

      # Iterate over entries
      def each(&block : Name, Base -> _)
        @entries.each { |k, v| yield k, v }
      end

      # Get all keys
      def keys : ::Array(Name)
        @entries.keys
      end

      # Get all values
      def values : ::Array(Base)
        @entries.values
      end

      def size : Int32
        @entries.size
      end

      def empty? : Bool
        @entries.empty?
      end

      def clear : self
        @entries.clear
        self
      end

      # Merge another dictionary into this one
      def merge!(other : Dictionary) : self
        @entries.merge!(other.@entries)
        self
      end

      def_equals_and_hash @entries
    end
  end
end
