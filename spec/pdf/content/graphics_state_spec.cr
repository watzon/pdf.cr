require "../../spec_helper"

describe PDF::Content::GraphicsState do
  describe PDF::Content::GraphicsState::LineCap do
    it "has correct values" do
      PDF::Content::GraphicsState::LineCap::Butt.value.should eq(0)
      PDF::Content::GraphicsState::LineCap::Round.value.should eq(1)
      PDF::Content::GraphicsState::LineCap::Square.value.should eq(2)
    end
  end

  describe PDF::Content::GraphicsState::LineJoin do
    it "has correct values" do
      PDF::Content::GraphicsState::LineJoin::Miter.value.should eq(0)
      PDF::Content::GraphicsState::LineJoin::Round.value.should eq(1)
      PDF::Content::GraphicsState::LineJoin::Bevel.value.should eq(2)
    end
  end

  describe PDF::Content::GraphicsState::BlendMode do
    it "converts to PDF names correctly" do
      PDF::Content::GraphicsState::BlendMode::Normal.to_pdf_name.should eq("Normal")
      PDF::Content::GraphicsState::BlendMode::Multiply.to_pdf_name.should eq("Multiply")
      PDF::Content::GraphicsState::BlendMode::Screen.to_pdf_name.should eq("Screen")
      PDF::Content::GraphicsState::BlendMode::Overlay.to_pdf_name.should eq("Overlay")
      PDF::Content::GraphicsState::BlendMode::Darken.to_pdf_name.should eq("Darken")
      PDF::Content::GraphicsState::BlendMode::Lighten.to_pdf_name.should eq("Lighten")
      PDF::Content::GraphicsState::BlendMode::ColorDodge.to_pdf_name.should eq("ColorDodge")
      PDF::Content::GraphicsState::BlendMode::ColorBurn.to_pdf_name.should eq("ColorBurn")
      PDF::Content::GraphicsState::BlendMode::HardLight.to_pdf_name.should eq("HardLight")
      PDF::Content::GraphicsState::BlendMode::SoftLight.to_pdf_name.should eq("SoftLight")
      PDF::Content::GraphicsState::BlendMode::Difference.to_pdf_name.should eq("Difference")
      PDF::Content::GraphicsState::BlendMode::Exclusion.to_pdf_name.should eq("Exclusion")
    end
  end

  describe PDF::Content::GraphicsState::RenderingIntent do
    it "converts to PDF names correctly" do
      PDF::Content::GraphicsState::RenderingIntent::AbsoluteColorimetric.to_pdf_name.should eq("AbsoluteColorimetric")
      PDF::Content::GraphicsState::RenderingIntent::RelativeColorimetric.to_pdf_name.should eq("RelativeColorimetric")
      PDF::Content::GraphicsState::RenderingIntent::Saturation.to_pdf_name.should eq("Saturation")
      PDF::Content::GraphicsState::RenderingIntent::Perceptual.to_pdf_name.should eq("Perceptual")
    end
  end

  describe PDF::Content::GraphicsState::TextRenderMode do
    it "has correct values" do
      PDF::Content::GraphicsState::TextRenderMode::Fill.value.should eq(0)
      PDF::Content::GraphicsState::TextRenderMode::Stroke.value.should eq(1)
      PDF::Content::GraphicsState::TextRenderMode::FillStroke.value.should eq(2)
      PDF::Content::GraphicsState::TextRenderMode::Invisible.value.should eq(3)
      PDF::Content::GraphicsState::TextRenderMode::FillClip.value.should eq(4)
      PDF::Content::GraphicsState::TextRenderMode::StrokeClip.value.should eq(5)
      PDF::Content::GraphicsState::TextRenderMode::FillStrokeClip.value.should eq(6)
      PDF::Content::GraphicsState::TextRenderMode::Clip.value.should eq(7)
    end
  end

  describe PDF::Content::GraphicsState::DashPattern do
    it "creates solid line by default" do
      pattern = PDF::Content::GraphicsState::DashPattern.new
      pattern.solid?.should be_true
      pattern.to_pdf.should eq("[] 0")
    end

    it "creates dashed pattern" do
      pattern = PDF::Content::GraphicsState::DashPattern.new([5.0, 3.0])
      pattern.solid?.should be_false
      pattern.to_pdf.should eq("[5.0 3.0] 0")
    end

    it "creates dashed pattern with phase" do
      pattern = PDF::Content::GraphicsState::DashPattern.new([5.0, 3.0], 2.0)
      pattern.to_pdf.should eq("[5.0 3.0] 2")
    end

    it "creates from integer array" do
      pattern = PDF::Content::GraphicsState::DashPattern.new([5, 3, 1, 3])
      pattern.to_pdf.should eq("[5.0 3.0 1.0 3.0] 0")
    end
  end
end
