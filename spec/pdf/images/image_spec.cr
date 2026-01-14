require "../../spec_helper"

describe PDF::Images::Image do
  describe ".load from path" do
    it "loads JPEG from .jpg extension" do
      image = PDF::Images::Image.load("spec/fixtures/images/test_rgb.jpg")
      image.should be_a(PDF::Images::JPEG)
      image.width.should eq(100)
      image.height.should eq(100)
    end

    it "loads JPEG from .jpeg extension" do
      # Create a symlink with .jpeg extension
      File.copy("spec/fixtures/images/test_rgb.jpg", "spec/fixtures/images/test_rgb.jpeg")
      begin
        image = PDF::Images::Image.load("spec/fixtures/images/test_rgb.jpeg")
        image.should be_a(PDF::Images::JPEG)
      ensure
        File.delete("spec/fixtures/images/test_rgb.jpeg")
      end
    end

    it "loads PNG from .png extension" do
      image = PDF::Images::Image.load("spec/fixtures/images/test_rgb.png")
      image.should be_a(PDF::Images::PNG)
      image.width.should eq(100)
      image.height.should eq(100)
    end
  end

  describe ".load from bytes" do
    it "auto-detects JPEG from magic bytes" do
      data = File.read("spec/fixtures/images/test_rgb.jpg").to_slice
      image = PDF::Images::Image.load(data)
      image.should be_a(PDF::Images::JPEG)
    end

    it "auto-detects PNG from magic bytes" do
      data = File.read("spec/fixtures/images/test_rgb.png").to_slice
      image = PDF::Images::Image.load(data)
      image.should be_a(PDF::Images::PNG)
    end

    it "raises on unknown format" do
      expect_raises(ArgumentError, /Unknown image format/) do
        PDF::Images::Image.load(Bytes[0x00, 0x01, 0x02, 0x03])
      end
    end
  end

  describe ".jpeg?" do
    it "returns true for JPEG data" do
      data = File.read("spec/fixtures/images/test_rgb.jpg").to_slice
      PDF::Images::Image.jpeg?(data).should be_true
    end

    it "returns false for PNG data" do
      data = File.read("spec/fixtures/images/test_rgb.png").to_slice
      PDF::Images::Image.jpeg?(data).should be_false
    end
  end

  describe ".png?" do
    it "returns true for PNG data" do
      data = File.read("spec/fixtures/images/test_rgb.png").to_slice
      PDF::Images::Image.png?(data).should be_true
    end

    it "returns false for JPEG data" do
      data = File.read("spec/fixtures/images/test_rgb.jpg").to_slice
      PDF::Images::Image.png?(data).should be_false
    end
  end
end
