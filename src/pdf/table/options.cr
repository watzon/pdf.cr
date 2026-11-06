module PDF
  class Table
    # Scalar value of one cell option or style key.
    alias OptionValue = String | Int32 | Float64 | Bool?

    # Cell options and styles in their normalized form.
    alias OptionHash = Hash(Symbol, OptionValue)

    # Converts cell and style options from hashes and named tuples to an
    # `OptionHash`.
    #
    # Array and tuple values expand to per-side keys, in the CSS order
    # top, right, bottom, left:
    #
    # - `padding: [t, r, b, l]` (or `[vertical, horizontal]`) sets
    #   `padding_top`, `padding_right`, `padding_bottom` and `padding_left`.
    # - `border_widths: [...]` sets `border_top_width` and the other sides.
    # - `border_colors: [...]` sets `border_top_color` and the other sides.
    # - `borders: [:top, :bottom]` becomes the string `"top bottom"`.
    #
    # Symbol values become strings, and integer and float values become
    # `Int32` and `Float64`.
    module Options
      # The four sides of a cell, in the order of per-side arrays.
      SIDES = {:top, :right, :bottom, :left}

      PADDING_KEYS      = {:padding_top, :padding_right, :padding_bottom, :padding_left}
      BORDER_WIDTH_KEYS = {:border_top_width, :border_right_width, :border_bottom_width, :border_left_width}
      BORDER_COLOR_KEYS = {:border_top_color, :border_right_color, :border_bottom_color, :border_left_color}

      # Normalizes the scalar options of *options*. Image and table values
      # are not scalar: use `.split` for cell data that can hold them.
      def self.normalize(options : Hash | NamedTuple) : OptionHash
        hash = OptionHash.new
        options.each { |key, value| store(hash, key, value) }
        hash
      end

      # Splits cell data into its normalized scalar options and its content
      # object (an image or a nested table), if it has one.
      def self.split(options : Hash | NamedTuple) : Tuple(OptionHash, Images::Base | Table?)
        hash = OptionHash.new
        object = nil
        options.each do |key, value|
          if value.is_a?(Images::Base) || value.is_a?(Table)
            object = value
          else
            store(hash, key, value)
          end
        end
        {hash, object}
      end

      # Converts a normalized option hash to the `Table#cell_style` type.
      def self.to_style(options : OptionHash) : Hash(Symbol, String | Float64 | Bool?)
        style = {} of Symbol => String | Float64 | Bool?
        options.each do |key, value|
          style[key] = value.is_a?(Int32) ? value.to_f : value
        end
        style
      end

      private def self.store(hash : OptionHash, key : Symbol, value : Array | Tuple) : Nil
        case key
        when :padding       then store_sides(hash, PADDING_KEYS, value) { |item| to_number(item) }
        when :border_widths then store_sides(hash, BORDER_WIDTH_KEYS, value) { |item| to_number(item) }
        when :border_colors then store_sides(hash, BORDER_COLOR_KEYS, value, &.to_s)
        when :borders       then hash[key] = value.join(' ', &.to_s)
        else
          raise ArgumentError.new("Table option #{key} does not accept a list")
        end
      end

      private def self.store(hash : OptionHash, key : Symbol, value : Int) : Nil
        hash[key] = value.to_i32
      end

      private def self.store(hash : OptionHash, key : Symbol, value : Float) : Nil
        hash[key] = value.to_f64
      end

      private def self.store(hash : OptionHash, key : Symbol, value : String | Bool?) : Nil
        hash[key] = value
      end

      private def self.store(hash : OptionHash, key : Symbol, value) : Nil
        hash[key] = value.to_s
      end

      # Expands a list of one, two or four values to the four per-side keys.
      private def self.store_sides(hash : OptionHash, keys, values, &) : Nil
        items = values.to_a
        expanded = case items.size
                   when 1 then [items[0], items[0], items[0], items[0]]
                   when 2 then [items[0], items[1], items[0], items[1]]
                   when 4 then items
                   else
                     raise ArgumentError.new("Per-side table options take 1, 2 or 4 values, not #{items.size}")
                   end
        keys.each_with_index { |key, index| hash[key] = yield expanded[index] }
      end

      private def self.to_number(value) : OptionValue
        case value
        when Int   then value.to_i32
        when Float then value.to_f64
        else
          raise ArgumentError.new("Expected a number in a per-side table option, not #{value.inspect}")
        end
      end
    end
  end
end
