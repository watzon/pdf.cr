require "../../spec_helper"

describe PDF::SVG::Color do
  describe ".parse" do
    it "parses hex colors (#RRGGBB)" do
      result = PDF::SVG::Color.parse("#FF0000")
      result.should_not be_nil
      result = result.not_nil!
      result[0].should be_close(1.0, 0.01)
      result[1].should be_close(0.0, 0.01)
      result[2].should be_close(0.0, 0.01)
    end

    it "parses short hex colors (#RGB)" do
      result = PDF::SVG::Color.parse("#F00")
      result.should_not be_nil
      result = result.not_nil!
      result[0].should be_close(1.0, 0.01)
      result[1].should be_close(0.0, 0.01)
      result[2].should be_close(0.0, 0.01)
    end

    it "parses named colors" do
      result = PDF::SVG::Color.parse("blue")
      result.should_not be_nil
      result = result.not_nil!
      result[0].should be_close(0.0, 0.01)
      result[1].should be_close(0.0, 0.01)
      result[2].should be_close(1.0, 0.01)
    end

    it "parses rgb() functional notation" do
      result = PDF::SVG::Color.parse("rgb(0, 128, 255)")
      result.should_not be_nil
      result = result.not_nil!
      result[0].should be_close(0.0, 0.01)
      result[1].should be_close(0.502, 0.01)
      result[2].should be_close(1.0, 0.01)
    end

    it "returns nil for 'none'" do
      PDF::SVG::Color.parse("none").should be_nil
    end

    it "returns nil for nil input" do
      PDF::SVG::Color.parse(nil).should be_nil
    end

    it "returns nil for empty string" do
      PDF::SVG::Color.parse("").should be_nil
    end
  end

  describe ".to_hex" do
    it "converts RGB tuple to hex string" do
      PDF::SVG::Color.to_hex(1.0, 0.0, 0.0).should eq("FF0000")
      PDF::SVG::Color.to_hex(0.0, 0.0, 1.0).should eq("0000FF")
      PDF::SVG::Color.to_hex(0.5, 0.5, 0.5).should eq("808080")
    end
  end
end
