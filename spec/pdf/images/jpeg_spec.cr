require "../../spec_helper"

describe PDF::Images::JPEG do
  describe ".load" do
    it "loads JPEG from file path" do
      jpeg = PDF::Images::JPEG.load("spec/fixtures/images/test_rgb.jpg")
      jpeg.width.should eq(100)
      jpeg.height.should eq(100)
      jpeg.components.should eq(3)
    end

    it "loads grayscale JPEG" do
      jpeg = PDF::Images::JPEG.load("spec/fixtures/images/test_gray.jpg")
      jpeg.width.should eq(100)
      jpeg.height.should eq(100)
      jpeg.components.should eq(1)
    end

    it "loads JPEG from bytes" do
      data = File.read("spec/fixtures/images/test_rgb.jpg").to_slice
      jpeg = PDF::Images::JPEG.load(data)
      jpeg.width.should eq(100)
      jpeg.height.should eq(100)
    end

    it "loads JPEG from IO" do
      File.open("spec/fixtures/images/test_rgb.jpg", "rb") do |file|
        jpeg = PDF::Images::JPEG.load(file)
        jpeg.width.should eq(100)
        jpeg.height.should eq(100)
      end
    end

    it "raises on invalid data" do
      expect_raises(ArgumentError, /Invalid JPEG/) do
        PDF::Images::JPEG.load(Bytes[0x00, 0x01, 0x02, 0x03])
      end
    end
  end

  describe "#color_space" do
    it "returns DeviceRGB for RGB JPEG" do
      jpeg = PDF::Images::JPEG.load("spec/fixtures/images/test_rgb.jpg")
      jpeg.color_space.value.should eq("DeviceRGB")
    end

    it "returns DeviceGray for grayscale JPEG" do
      jpeg = PDF::Images::JPEG.load("spec/fixtures/images/test_gray.jpg")
      jpeg.color_space.value.should eq("DeviceGray")
    end
  end

  describe "#has_alpha?" do
    it "returns false for JPEG" do
      jpeg = PDF::Images::JPEG.load("spec/fixtures/images/test_rgb.jpg")
      jpeg.has_alpha?.should be_false
    end
  end

  describe "#bits_per_component" do
    it "returns 8" do
      jpeg = PDF::Images::JPEG.load("spec/fixtures/images/test_rgb.jpg")
      jpeg.bits_per_component.should eq(8)
    end
  end

  describe "#to_stream" do
    it "creates stream with DCTDecode filter" do
      jpeg = PDF::Images::JPEG.load("spec/fixtures/images/test_rgb.jpg")
      stream = jpeg.to_stream

      stream["Type"].as(PDF::Objects::Name).value.should eq("XObject")
      stream["Subtype"].as(PDF::Objects::Name).value.should eq("Image")
      stream["Width"].as(PDF::Objects::Number).value.should eq(100)
      stream["Height"].as(PDF::Objects::Number).value.should eq(100)
      stream["ColorSpace"].as(PDF::Objects::Name).value.should eq("DeviceRGB")
      stream["BitsPerComponent"].as(PDF::Objects::Number).value.should eq(8)

      # Stream should contain DCTDecode in output
      stream.to_pdf.should contain("/DCTDecode")
    end

    it "preserves original JPEG data" do
      original_data = File.read("spec/fixtures/images/test_rgb.jpg").to_slice
      jpeg = PDF::Images::JPEG.load(original_data)
      stream = jpeg.to_stream

      # The encoded data should be the same as original (DCT passthrough)
      stream.encoded_data.should eq(original_data)
    end
  end

  describe "#soft_mask_stream" do
    it "returns nil for JPEG" do
      jpeg = PDF::Images::JPEG.load("spec/fixtures/images/test_rgb.jpg")
      jpeg.soft_mask_stream.should be_nil
    end
  end
end
