require "../../spec_helper"

describe PDF::Content::Color do
  describe ".named" do
    it "returns RGB values for named colors" do
      PDF::Content::Color.named(:red).should eq({1.0, 0.0, 0.0})
      PDF::Content::Color.named(:green).should eq({0.0, 1.0, 0.0})
      PDF::Content::Color.named(:blue).should eq({0.0, 0.0, 1.0})
      PDF::Content::Color.named(:black).should eq({0.0, 0.0, 0.0})
      PDF::Content::Color.named(:white).should eq({1.0, 1.0, 1.0})
    end

    it "raises for unknown colors" do
      expect_raises(ArgumentError, /Unknown color/) do
        PDF::Content::Color.named(:nonexistent)
      end
    end
  end

  describe ".from_hex" do
    it "parses 6-digit hex colors" do
      PDF::Content::Color.from_hex("#FF0000").should eq({1.0, 0.0, 0.0})
      PDF::Content::Color.from_hex("#00FF00").should eq({0.0, 1.0, 0.0})
      PDF::Content::Color.from_hex("#0000FF").should eq({0.0, 0.0, 1.0})
      PDF::Content::Color.from_hex("#FFFFFF").should eq({1.0, 1.0, 1.0})
      PDF::Content::Color.from_hex("#000000").should eq({0.0, 0.0, 0.0})
    end

    it "parses 6-digit hex colors without #" do
      PDF::Content::Color.from_hex("FF0000").should eq({1.0, 0.0, 0.0})
    end

    it "parses 3-digit hex colors" do
      PDF::Content::Color.from_hex("#F00").should eq({1.0, 0.0, 0.0})
      PDF::Content::Color.from_hex("#0F0").should eq({0.0, 1.0, 0.0})
      PDF::Content::Color.from_hex("#00F").should eq({0.0, 0.0, 1.0})
    end

    it "parses 3-digit hex colors without #" do
      PDF::Content::Color.from_hex("F00").should eq({1.0, 0.0, 0.0})
    end

    it "raises for invalid hex colors" do
      expect_raises(ArgumentError) do
        PDF::Content::Color.from_hex("#GG0000")
      end
    end

    it "raises for wrong length hex colors" do
      expect_raises(ArgumentError, /Invalid hex color/) do
        PDF::Content::Color.from_hex("#FF00")
      end
    end
  end

  describe ".rgb_to_gray" do
    it "converts RGB to grayscale using luminance formula" do
      gray = PDF::Content::Color.rgb_to_gray(1.0, 1.0, 1.0)
      gray.should be_close(1.0, 0.001)

      gray = PDF::Content::Color.rgb_to_gray(0.0, 0.0, 0.0)
      gray.should be_close(0.0, 0.001)

      # Red contributes about 21%
      gray = PDF::Content::Color.rgb_to_gray(1.0, 0.0, 0.0)
      gray.should be_close(0.2126, 0.001)

      # Green contributes about 72%
      gray = PDF::Content::Color.rgb_to_gray(0.0, 1.0, 0.0)
      gray.should be_close(0.7152, 0.001)

      # Blue contributes about 7%
      gray = PDF::Content::Color.rgb_to_gray(0.0, 0.0, 1.0)
      gray.should be_close(0.0722, 0.001)
    end
  end

  describe ".rgb_to_cmyk" do
    it "converts RGB to CMYK" do
      # Red
      c, m, y, k = PDF::Content::Color.rgb_to_cmyk(1.0, 0.0, 0.0)
      c.should be_close(0.0, 0.001)
      m.should be_close(1.0, 0.001)
      y.should be_close(1.0, 0.001)
      k.should be_close(0.0, 0.001)

      # Black
      c, m, y, k = PDF::Content::Color.rgb_to_cmyk(0.0, 0.0, 0.0)
      c.should be_close(0.0, 0.001)
      m.should be_close(0.0, 0.001)
      y.should be_close(0.0, 0.001)
      k.should be_close(1.0, 0.001)

      # White
      c, m, y, k = PDF::Content::Color.rgb_to_cmyk(1.0, 1.0, 1.0)
      c.should be_close(0.0, 0.001)
      m.should be_close(0.0, 0.001)
      y.should be_close(0.0, 0.001)
      k.should be_close(0.0, 0.001)
    end
  end

  describe ".cmyk_to_rgb" do
    it "converts CMYK to RGB" do
      # Cyan
      r, g, b = PDF::Content::Color.cmyk_to_rgb(1.0, 0.0, 0.0, 0.0)
      r.should be_close(0.0, 0.001)
      g.should be_close(1.0, 0.001)
      b.should be_close(1.0, 0.001)

      # Black (full key)
      r, g, b = PDF::Content::Color.cmyk_to_rgb(0.0, 0.0, 0.0, 1.0)
      r.should be_close(0.0, 0.001)
      g.should be_close(0.0, 0.001)
      b.should be_close(0.0, 0.001)
    end
  end

  describe ".clamp" do
    it "clamps values to [0.0, 1.0]" do
      PDF::Content::Color.clamp(-0.5).should eq(0.0)
      PDF::Content::Color.clamp(0.0).should eq(0.0)
      PDF::Content::Color.clamp(0.5).should eq(0.5)
      PDF::Content::Color.clamp(1.0).should eq(1.0)
      PDF::Content::Color.clamp(1.5).should eq(1.0)
    end
  end
end
