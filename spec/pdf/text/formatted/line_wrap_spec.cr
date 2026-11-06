require "../../../spec_helper"

module LineWrapSpecHelper
  def self.make_hash(text : String, styles : Array(Symbol) = [] of Symbol) : PDF::Text::Formatted::FragmentHash
    hash = PDF::Text::Formatted::FragmentHash.new
    hash[:text] = text
    hash[:styles] = styles
    hash
  end

  def self.make_measurer : PDF::Text::Formatted::FontMeasurer
    doc = PDF::Document.new
    PDF::Text::Formatted::FontMeasurer.new(doc)
  end
end

describe PDF::Text::Formatted::LineWrap do
  describe "#tokenize" do
    it "splits on spaces" do
      lw = PDF::Text::Formatted::LineWrap.new
      tokens = lw.tokenize("hello world")
      tokens.should eq(["hello", " ", "world"])
    end

    it "splits on hyphens keeping them with the word" do
      lw = PDF::Text::Formatted::LineWrap.new
      tokens = lw.tokenize("well-known")
      tokens.should eq(["well-", "known"])
    end

    it "handles single word" do
      lw = PDF::Text::Formatted::LineWrap.new
      tokens = lw.tokenize("hello")
      tokens.should eq(["hello"])
    end

    it "handles empty string" do
      lw = PDF::Text::Formatted::LineWrap.new
      tokens = lw.tokenize("")
      tokens.should be_empty
    end
  end

  describe "#wrap_line" do
    it "wraps text that fits on one line" do
      lw = PDF::Text::Formatted::LineWrap.new
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = LineWrapSpecHelper.make_measurer

      arranger.format_array = [LineWrapSpecHelper.make_hash("Hello World")]
      line = lw.wrap_line(arranger: arranger, width: 500.0, font_measurer: measurer)
      line.should eq("Hello World")
      arranger.finished?.should be_true
    end

    it "wraps text that exceeds the width" do
      lw = PDF::Text::Formatted::LineWrap.new
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = LineWrapSpecHelper.make_measurer

      arranger.format_array = [LineWrapSpecHelper.make_hash("Hello World")]
      line = lw.wrap_line(arranger: arranger, width: 40.0, font_measurer: measurer)
      line.size.should be < "Hello World".size
      arranger.finished?.should be_false
    end

    it "handles newlines" do
      lw = PDF::Text::Formatted::LineWrap.new
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = LineWrapSpecHelper.make_measurer

      arranger.format_array = [LineWrapSpecHelper.make_hash("Hello\nWorld")]
      line = lw.wrap_line(arranger: arranger, width: 500.0, font_measurer: measurer)
      line.should eq("Hello")
      arranger.finished?.should be_false
    end

    it "handles multiple fragments" do
      lw = PDF::Text::Formatted::LineWrap.new
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = LineWrapSpecHelper.make_measurer

      arranger.format_array = [LineWrapSpecHelper.make_hash("Hello "), LineWrapSpecHelper.make_hash("World", [:bold])]
      line = lw.wrap_line(arranger: arranger, width: 500.0, font_measurer: measurer)
      line.should eq("Hello World")
    end

    it "reports correct width" do
      lw = PDF::Text::Formatted::LineWrap.new
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = LineWrapSpecHelper.make_measurer

      arranger.format_array = [LineWrapSpecHelper.make_hash("Hello")]
      lw.wrap_line(arranger: arranger, width: 500.0, font_measurer: measurer)
      lw.width.should be > 0.0
    end

    it "reports correct space count" do
      lw = PDF::Text::Formatted::LineWrap.new
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = LineWrapSpecHelper.make_measurer

      arranger.format_array = [LineWrapSpecHelper.make_hash("Hello World Foo")]
      lw.wrap_line(arranger: arranger, width: 500.0, font_measurer: measurer)
      lw.space_count.should eq(2)
    end

    it "strips leading whitespace on the first fragment" do
      lw = PDF::Text::Formatted::LineWrap.new
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = LineWrapSpecHelper.make_measurer

      arranger.format_array = [LineWrapSpecHelper.make_hash("  Hello")]
      line = lw.wrap_line(arranger: arranger, width: 500.0, font_measurer: measurer)
      line.should eq("Hello")
    end
  end
end
