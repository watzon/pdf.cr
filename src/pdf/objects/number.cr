module PDF
  module Objects
    # Represents a PDF numeric object (integer or real).
    #
    # PDF supports both integer and real (floating-point) numbers.
    # Integers are written without a decimal point.
    # Reals are written with a decimal point and optional sign.
    #
    # ```
    # int = PDF::Objects::Number.new(42)
    # int.to_pdf # => "42"
    #
    # real = PDF::Objects::Number.new(3.14159)
    # real.to_pdf # => "3.14159"
    #
    # negative = PDF::Objects::Number.new(-17.5)
    # negative.to_pdf # => "-17.5"
    # ```
    #
    # Note: PDF reals have limited precision. Very small or very large
    # values may lose precision when serialized.
    class Number < Base
      # Maximum decimal places for real numbers
      MAX_DECIMAL_PLACES = 6

      getter value : Float64 | Int64 | Int32

      def initialize(value : Int)
        @value = value.to_i64
      end

      def initialize(value : Float)
        @value = value.to_f64
      end

      def to_pdf : ::String
        case v = @value
        when Int64, Int32
          v.to_s
        when Float64
          format_real(v)
        else
          v.to_s
        end
      end

      # Returns true if this is an integer value
      def integer? : Bool
        @value.is_a?(Int64) || @value.is_a?(Int32)
      end

      # Returns true if this is a real (float) value
      def real? : Bool
        @value.is_a?(Float64)
      end

      # Returns the value as Int64, truncating if necessary
      def to_i64 : Int64
        case v = @value
        when Int64   then v
        when Int32   then v.to_i64
        when Float64 then v.to_i64
        else
          raise "Unexpected value type"
        end
      end

      # Returns the value as Float64
      def to_f64 : Float64
        case v = @value
        when Float64      then v
        when Int64, Int32 then v.to_f64
        else
          raise "Unexpected value type"
        end
      end

      def_equals_and_hash @value

      private def format_real(value : Float64) : String
        # Check if it's effectively an integer
        if value.finite? && value == value.round
          return value.to_i64.to_s
        end

        # Format with limited precision, removing trailing zeros
        formatted = "%.#{MAX_DECIMAL_PLACES}f" % value

        # Remove trailing zeros after decimal point
        if formatted.includes?('.')
          formatted = formatted.rstrip('0')
          # Remove trailing decimal point if no decimals left
          formatted = formatted.rstrip('.')
        end

        formatted
      end
    end
  end
end
