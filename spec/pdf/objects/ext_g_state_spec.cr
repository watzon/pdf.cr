require "../../spec_helper"

describe PDF::Objects::ExtGState do
  describe "initialization" do
    it "creates empty ExtGState" do
      gs = PDF::Objects::ExtGState.new
      gs.fill_opacity.should be_nil
      gs.stroke_opacity.should be_nil
      gs.blend_mode.should be_nil
    end
  end

  describe ".with_opacity" do
    it "creates ExtGState with fill opacity" do
      gs = PDF::Objects::ExtGState.with_opacity(fill: 0.5)
      gs.fill_opacity.should eq(0.5)
      gs.stroke_opacity.should be_nil
    end

    it "creates ExtGState with stroke opacity" do
      gs = PDF::Objects::ExtGState.with_opacity(stroke: 0.8)
      gs.fill_opacity.should be_nil
      gs.stroke_opacity.should eq(0.8)
    end

    it "creates ExtGState with both opacities" do
      gs = PDF::Objects::ExtGState.with_opacity(fill: 0.5, stroke: 0.8)
      gs.fill_opacity.should eq(0.5)
      gs.stroke_opacity.should eq(0.8)
    end
  end

  describe ".with_blend_mode" do
    it "creates ExtGState with blend mode" do
      gs = PDF::Objects::ExtGState.with_blend_mode(PDF::Content::GraphicsState::BlendMode::Multiply)
      gs.blend_mode.should eq(PDF::Content::GraphicsState::BlendMode::Multiply)
    end
  end

  describe "#to_dictionary" do
    it "creates dictionary with Type" do
      gs = PDF::Objects::ExtGState.new
      dict = gs.to_dictionary
      dict["Type"].should be_a(PDF::Objects::Name)
      dict["Type"].as(PDF::Objects::Name).value.should eq("ExtGState")
    end

    it "includes fill opacity (ca)" do
      gs = PDF::Objects::ExtGState.new
      gs.fill_opacity = 0.5
      dict = gs.to_dictionary
      dict["ca"].should be_a(PDF::Objects::Number)
      dict["ca"].as(PDF::Objects::Number).value.should eq(0.5)
    end

    it "includes stroke opacity (CA)" do
      gs = PDF::Objects::ExtGState.new
      gs.stroke_opacity = 0.8
      dict = gs.to_dictionary
      dict["CA"].should be_a(PDF::Objects::Number)
      dict["CA"].as(PDF::Objects::Number).value.should eq(0.8)
    end

    it "includes blend mode (BM)" do
      gs = PDF::Objects::ExtGState.new
      gs.blend_mode = PDF::Content::GraphicsState::BlendMode::Screen
      dict = gs.to_dictionary
      dict["BM"].should be_a(PDF::Objects::Name)
      dict["BM"].as(PDF::Objects::Name).value.should eq("Screen")
    end

    it "includes line width (LW)" do
      gs = PDF::Objects::ExtGState.new
      gs.line_width = 2.5
      dict = gs.to_dictionary
      dict["LW"].should be_a(PDF::Objects::Number)
      dict["LW"].as(PDF::Objects::Number).value.should eq(2.5)
    end

    it "includes line cap (LC)" do
      gs = PDF::Objects::ExtGState.new
      gs.line_cap = PDF::Content::GraphicsState::LineCap::Round
      dict = gs.to_dictionary
      dict["LC"].should be_a(PDF::Objects::Number)
      dict["LC"].as(PDF::Objects::Number).value.should eq(1)
    end

    it "includes line join (LJ)" do
      gs = PDF::Objects::ExtGState.new
      gs.line_join = PDF::Content::GraphicsState::LineJoin::Bevel
      dict = gs.to_dictionary
      dict["LJ"].should be_a(PDF::Objects::Number)
      dict["LJ"].as(PDF::Objects::Number).value.should eq(2)
    end

    it "includes miter limit (ML)" do
      gs = PDF::Objects::ExtGState.new
      gs.miter_limit = 5.0
      dict = gs.to_dictionary
      dict["ML"].should be_a(PDF::Objects::Number)
      dict["ML"].as(PDF::Objects::Number).value.should eq(5.0)
    end

    it "includes rendering intent (RI)" do
      gs = PDF::Objects::ExtGState.new
      gs.rendering_intent = PDF::Content::GraphicsState::RenderingIntent::Perceptual
      dict = gs.to_dictionary
      dict["RI"].should be_a(PDF::Objects::Name)
      dict["RI"].as(PDF::Objects::Name).value.should eq("Perceptual")
    end

    it "includes overprint mode (OPM)" do
      gs = PDF::Objects::ExtGState.new
      gs.overprint_mode = 1
      dict = gs.to_dictionary
      dict["OPM"].should be_a(PDF::Objects::Number)
      dict["OPM"].as(PDF::Objects::Number).value.should eq(1)
    end

    it "includes stroke overprint (OP)" do
      gs = PDF::Objects::ExtGState.new
      gs.stroke_overprint = true
      dict = gs.to_dictionary
      dict["OP"].should be_a(PDF::Objects::Boolean)
      dict["OP"].as(PDF::Objects::Boolean).value.should be_true
    end

    it "includes fill overprint (op)" do
      gs = PDF::Objects::ExtGState.new
      gs.fill_overprint = true
      dict = gs.to_dictionary
      # The lowercase "op" is used for fill overprint
      # Check it's in the dictionary by checking for the value using raw key
      found = false
      dict.each do |k, v|
        if k.value == "op"
          v.should be_a(PDF::Objects::Boolean)
          v.as(PDF::Objects::Boolean).value.should be_true
          found = true
        end
      end
      found.should be_true
    end
  end

  describe "#to_pdf" do
    it "generates valid PDF output" do
      gs = PDF::Objects::ExtGState.new
      gs.fill_opacity = 0.5
      pdf = gs.to_pdf
      pdf.should contain("/Type /ExtGState")
      pdf.should contain("/ca 0.5")
    end
  end

  describe "#hash_key" do
    it "generates consistent hash for same properties" do
      gs1 = PDF::Objects::ExtGState.new
      gs1.fill_opacity = 0.5
      gs1.blend_mode = PDF::Content::GraphicsState::BlendMode::Multiply

      gs2 = PDF::Objects::ExtGState.new
      gs2.fill_opacity = 0.5
      gs2.blend_mode = PDF::Content::GraphicsState::BlendMode::Multiply

      gs1.hash_key.should eq(gs2.hash_key)
    end

    it "generates different hash for different properties" do
      gs1 = PDF::Objects::ExtGState.new
      gs1.fill_opacity = 0.5

      gs2 = PDF::Objects::ExtGState.new
      gs2.fill_opacity = 0.8

      gs1.hash_key.should_not eq(gs2.hash_key)
    end
  end
end
