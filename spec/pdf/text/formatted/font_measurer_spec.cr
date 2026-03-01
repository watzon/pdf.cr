require "../../../spec_helper"

module FontMeasurerSpecHelper
  def self.make_measurer : PDF::Text::Formatted::FontMeasurer
    doc = PDF::Document.new
    PDF::Text::Formatted::FontMeasurer.new(doc)
  end
end

describe PDF::Text::Formatted::FontMeasurer do
  describe "#measure_width" do
    it "measures the width of plain text" do
      measurer = FontMeasurerSpecHelper.make_measurer
      state = PDF::Text::Formatted::FormatState.new
      width = measurer.measure_width("Hello", state)
      width.should be > 0.0
    end

    it "returns 0 for empty text" do
      measurer = FontMeasurerSpecHelper.make_measurer
      state = PDF::Text::Formatted::FormatState.new
      width = measurer.measure_width("", state)
      width.should eq(0.0)
    end

    it "measures bold text" do
      measurer = FontMeasurerSpecHelper.make_measurer
      normal_state = PDF::Text::Formatted::FormatState.new
      bold_state = PDF::Text::Formatted::FormatState.new(styles: [:bold])

      normal_width = measurer.measure_width("Hello", normal_state)
      bold_width = measurer.measure_width("Hello", bold_state)

      normal_width.should be > 0.0
      bold_width.should be > 0.0
    end

    it "respects font size override" do
      measurer = FontMeasurerSpecHelper.make_measurer
      small_state = PDF::Text::Formatted::FormatState.new(size: 8.0)
      large_state = PDF::Text::Formatted::FormatState.new(size: 24.0)

      small_width = measurer.measure_width("Hello", small_state)
      large_width = measurer.measure_width("Hello", large_state)

      large_width.should be > small_width
    end

    it "reduces size for subscript text" do
      measurer = FontMeasurerSpecHelper.make_measurer
      normal_state = PDF::Text::Formatted::FormatState.new
      sub_state = PDF::Text::Formatted::FormatState.new(styles: [:subscript])

      normal_width = measurer.measure_width("Hello", normal_state)
      sub_width = measurer.measure_width("Hello", sub_state)

      sub_width.should be < normal_width
    end

    it "reduces size for superscript text" do
      measurer = FontMeasurerSpecHelper.make_measurer
      normal_state = PDF::Text::Formatted::FormatState.new
      super_state = PDF::Text::Formatted::FormatState.new(styles: [:superscript])

      normal_width = measurer.measure_width("Hello", normal_state)
      super_width = measurer.measure_width("Hello", super_state)

      super_width.should be < normal_width
    end
  end

  describe "#metrics" do
    it "returns line height, ascender, and descender" do
      measurer = FontMeasurerSpecHelper.make_measurer
      state = PDF::Text::Formatted::FormatState.new

      metrics = measurer.metrics(state)
      metrics[:line_height].should be > 0.0
      metrics[:ascender].should be > 0.0
      metrics[:descender].should be > 0.0
    end

    it "scales metrics with font size" do
      measurer = FontMeasurerSpecHelper.make_measurer
      small_state = PDF::Text::Formatted::FormatState.new(size: 8.0)
      large_state = PDF::Text::Formatted::FormatState.new(size: 24.0)

      small_metrics = measurer.metrics(small_state)
      large_metrics = measurer.metrics(large_state)

      large_metrics[:line_height].should be > small_metrics[:line_height]
    end
  end
end
