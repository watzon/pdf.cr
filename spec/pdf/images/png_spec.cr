require "../../spec_helper"

describe PDF::Images::PNG do
  describe ".load" do
    it "loads PNG from file path" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")
      png.width.should eq(100)
      png.height.should eq(100)
    end

    it "loads PNG with alpha from file path" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgba.png")
      png.width.should eq(100)
      png.height.should eq(100)
      png.has_alpha?.should be_true
    end

    it "loads PNG from bytes" do
      data = File.read("spec/fixtures/images/test_rgb.png").to_slice
      png = PDF::Images::PNG.load(data)
      png.width.should eq(100)
      png.height.should eq(100)
    end

    it "loads PNG from IO" do
      File.open("spec/fixtures/images/test_rgb.png", "rb") do |file|
        png = PDF::Images::PNG.load(file)
        png.width.should eq(100)
        png.height.should eq(100)
      end
    end
  end

  describe "#color_space" do
    it "returns DeviceRGB for RGB PNG" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")
      png.color_space.value.should eq("DeviceRGB")
    end
  end

  describe "#has_alpha?" do
    it "returns true for RGBA PNG" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgba.png")
      png.has_alpha?.should be_true
    end

    it "returns false for RGB PNG" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")
      png.has_alpha?.should be_false
    end
  end

  describe "#bits_per_component" do
    it "returns 8" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")
      png.bits_per_component.should eq(8)
    end
  end

  describe "#rgb_data" do
    it "contains correct RGB data size" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")
      # 100x100 pixels * 3 bytes (RGB) = 30000 bytes
      png.rgb_data.size.should eq(100 * 100 * 3)
    end
  end

  describe "#alpha_data" do
    it "is nil for RGB PNG" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")
      png.alpha_data.should be_nil
    end

    it "contains alpha data for RGBA PNG" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgba.png")
      alpha = png.alpha_data
      alpha.should_not be_nil
      # 100x100 pixels * 1 byte (alpha) = 10000 bytes
      alpha.not_nil!.size.should eq(100 * 100)
    end
  end

  describe "#to_stream" do
    it "creates stream with FlateDecode filter" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")
      stream = png.to_stream

      stream["Type"].as(PDF::Objects::Name).value.should eq("XObject")
      stream["Subtype"].as(PDF::Objects::Name).value.should eq("Image")
      stream["Width"].as(PDF::Objects::Number).value.should eq(100)
      stream["Height"].as(PDF::Objects::Number).value.should eq(100)
      stream["ColorSpace"].as(PDF::Objects::Name).value.should eq("DeviceRGB")
      stream["BitsPerComponent"].as(PDF::Objects::Number).value.should eq(8)

      # Stream should contain FlateDecode in output
      stream.to_pdf.should contain("/FlateDecode")
    end

    it "compresses image data" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")
      stream = png.to_stream

      # Compressed data should be smaller than uncompressed RGB data
      stream.encoded_data.size.should be < png.rgb_data.size
    end
  end

  describe "#soft_mask_stream" do
    it "returns nil for RGB PNG" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgb.png")
      png.soft_mask_stream.should be_nil
    end

    it "returns soft mask stream for RGBA PNG" do
      png = PDF::Images::PNG.load("spec/fixtures/images/test_rgba.png")
      mask = png.soft_mask_stream
      mask.should_not be_nil

      mask = mask.not_nil!
      mask["Type"].as(PDF::Objects::Name).value.should eq("XObject")
      mask["Subtype"].as(PDF::Objects::Name).value.should eq("Image")
      mask["Width"].as(PDF::Objects::Number).value.should eq(100)
      mask["Height"].as(PDF::Objects::Number).value.should eq(100)
      mask["ColorSpace"].as(PDF::Objects::Name).value.should eq("DeviceGray")
      mask["BitsPerComponent"].as(PDF::Objects::Number).value.should eq(8)
    end
  end
end
