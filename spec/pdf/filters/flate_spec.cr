require "../../spec_helper"

describe PDF::Filters::Flate do
  describe "#name" do
    it "returns FlateDecode" do
      filter = PDF::Filters::Flate.new
      filter.name.to_pdf.should eq("/FlateDecode")
    end
  end

  describe "#encode" do
    it "compresses data" do
      filter = PDF::Filters::Flate.new
      original = "Hello, World! This is a test of compression."
      compressed = filter.encode(original.to_slice)

      # Compressed data should be smaller or similar size for small inputs
      # (very small inputs may actually grow due to zlib header)
      compressed.should_not eq(original.to_slice)
    end

    it "handles empty data" do
      filter = PDF::Filters::Flate.new
      compressed = filter.encode(Bytes.empty)
      compressed.should eq(Bytes.empty)
    end

    it "handles repetitive data well" do
      filter = PDF::Filters::Flate.new
      # Highly repetitive data should compress significantly
      original = ("AAAA" * 1000).to_slice
      compressed = filter.encode(original)

      compressed.size.should be < (original.size / 2)
    end
  end

  describe "#decode" do
    it "decompresses data" do
      filter = PDF::Filters::Flate.new
      original = "Hello, World! This is a test of decompression."

      compressed = filter.encode(original.to_slice)
      decompressed = filter.decode(compressed)

      String.new(decompressed).should eq(original)
    end

    it "handles empty data" do
      filter = PDF::Filters::Flate.new
      decompressed = filter.decode(Bytes.empty)
      decompressed.should eq(Bytes.empty)
    end

    it "round-trips binary data" do
      filter = PDF::Filters::Flate.new
      original = Bytes.new(256) { |i| i.to_u8 }

      compressed = filter.encode(original)
      decompressed = filter.decode(compressed)

      decompressed.should eq(original)
    end

    it "round-trips large data" do
      filter = PDF::Filters::Flate.new
      # 1MB of random-ish data
      original = Bytes.new(1024 * 1024) { |i| ((i * 17 + 31) % 256).to_u8 }

      compressed = filter.encode(original)
      decompressed = filter.decode(compressed)

      decompressed.should eq(original)
    end
  end

  describe "compression level" do
    it "accepts custom compression level" do
      filter = PDF::Filters::Flate.new(level: 9)
      filter.level.should eq(9)
    end

    it "uses default compression level" do
      filter = PDF::Filters::Flate.new
      filter.level.should eq(Compress::Zlib::DEFAULT_COMPRESSION)
    end

    it "higher compression produces smaller output for large repetitive data" do
      data = ("Hello World! " * 10000).to_slice

      low = PDF::Filters::Flate.new(level: 1)
      high = PDF::Filters::Flate.new(level: 9)

      low_compressed = low.encode(data)
      high_compressed = high.encode(data)

      # Higher compression should produce smaller or equal output
      high_compressed.size.should be <= low_compressed.size
    end
  end
end
