require "../../spec_helper"

describe PDF::Objects::Stream do
  describe "#to_pdf" do
    it "serializes with string data" do
      stream = PDF::Objects::Stream.new
      stream.data = "Hello, World!"

      pdf = stream.to_pdf
      pdf.should contain("<</Length 13>>")
      pdf.should contain("stream\n")
      pdf.should contain("Hello, World!")
      pdf.should contain("\nendstream")
    end

    it "serializes with empty data" do
      stream = PDF::Objects::Stream.new
      pdf = stream.to_pdf

      pdf.should contain("<</Length 0>>")
      pdf.should contain("stream\n")
      pdf.should contain("\nendstream")
    end

    it "serializes with binary data" do
      stream = PDF::Objects::Stream.new
      stream.data = Bytes[0x00, 0x01, 0x02, 0xFF]

      pdf = stream.to_pdf
      pdf.should contain("<</Length 4>>")
    end

    it "includes custom dictionary entries" do
      stream = PDF::Objects::Stream.new
      stream.data = "test"
      stream["Type"] = PDF::Objects::Name.new("XObject")
      stream["Subtype"] = PDF::Objects::Name.new("Image")

      pdf = stream.to_pdf
      pdf.should contain("/Type /XObject")
      pdf.should contain("/Subtype /Image")
      pdf.should contain("/Length 4")
    end
  end

  describe "with FlateDecode filter" do
    it "compresses the data" do
      stream = PDF::Objects::Stream.new
      original_data = "Hello, World! " * 100 # Repetitive data compresses well
      stream.data = original_data
      stream.add_filter(PDF::Filters::Flate.new)

      # Check encoded data is smaller than original
      encoded = stream.encoded_data
      encoded.size.should be < original_data.bytesize

      # Verify we can round-trip the data
      filter = PDF::Filters::Flate.new
      decoded = filter.decode(encoded)
      ::String.new(decoded).should eq(original_data)
    end

    it "includes filter in dictionary" do
      stream = PDF::Objects::Stream.new
      stream.data = "test"
      stream.add_filter(PDF::Filters::Flate.new)

      pdf = stream.to_pdf
      pdf.should contain("/Filter /FlateDecode")
    end
  end

  describe "#data=" do
    it "accepts string" do
      stream = PDF::Objects::Stream.new
      stream.data = "Hello"
      stream.data.should eq("Hello".to_slice)
    end

    it "accepts bytes" do
      stream = PDF::Objects::Stream.new
      bytes = Bytes[1, 2, 3]
      stream.data = bytes
      stream.data.should eq(bytes)
    end

    it "invalidates encoded cache" do
      stream = PDF::Objects::Stream.new
      stream.data = "First"
      stream.add_filter(PDF::Filters::Flate.new)

      first_encoded = stream.encoded_data.dup

      stream.data = "Second data that is different"
      second_encoded = stream.encoded_data

      first_encoded.should_not eq(second_encoded)
    end
  end

  describe "#encoded_data" do
    it "returns raw data without filters" do
      stream = PDF::Objects::Stream.new
      stream.data = "Hello"
      stream.encoded_data.should eq("Hello".to_slice)
    end

    it "returns compressed data with filter" do
      stream = PDF::Objects::Stream.new
      stream.data = "Hello, World!"
      stream.add_filter(PDF::Filters::Flate.new)

      encoded = stream.encoded_data
      encoded.should_not eq("Hello, World!".to_slice)

      # Verify we can decode it back
      filter = PDF::Filters::Flate.new
      decoded = filter.decode(encoded)
      String.new(decoded).should eq("Hello, World!")
    end

    it "is cached" do
      stream = PDF::Objects::Stream.new
      stream.data = "Hello"
      stream.add_filter(PDF::Filters::Flate.new)

      # Same object should be returned
      first = stream.encoded_data
      second = stream.encoded_data
      first.should be(second)
    end
  end

  describe "dictionary access" do
    it "supports []= with Name" do
      stream = PDF::Objects::Stream.new
      stream[PDF::Objects::Name.new("Type")] = PDF::Objects::Name.new("XObject")
      stream.dictionary["Type"].should eq(PDF::Objects::Name.new("XObject"))
    end

    it "supports []= with String" do
      stream = PDF::Objects::Stream.new
      stream["Type"] = PDF::Objects::Name.new("XObject")
      stream.dictionary["Type"].should eq(PDF::Objects::Name.new("XObject"))
    end

    it "supports [] with Name" do
      stream = PDF::Objects::Stream.new
      stream["Type"] = PDF::Objects::Name.new("XObject")
      stream[PDF::Objects::Name.new("Type")].should eq(PDF::Objects::Name.new("XObject"))
    end

    it "supports []? with Name" do
      stream = PDF::Objects::Stream.new
      stream[PDF::Objects::Name.new("Missing")]?.should be_nil
    end
  end
end
