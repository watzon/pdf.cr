require "../../../spec_helper"

module ArrangerSpecHelper
  def self.make_hash(text : String, styles : Array(Symbol) = [] of Symbol, color : String? = nil) : PDF::Text::Formatted::FragmentHash
    hash = PDF::Text::Formatted::FragmentHash.new
    hash[:text] = text
    hash[:styles] = styles
    hash[:color] = color
    hash
  end

  def self.make_measurer : PDF::Text::Formatted::FontMeasurer
    doc = PDF::Document.new
    PDF::Text::Formatted::FontMeasurer.new(doc)
  end
end

describe PDF::Text::Formatted::Arranger do
  describe "#format_array=" do
    it "splits text on newlines" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello\nWorld")]
      # "Hello", "\n", "World" = 3 entries
      arranger.unconsumed.size.should eq(3)
      arranger.unconsumed[0][:text].should eq("Hello")
      arranger.unconsumed[1][:text].should eq("\n")
      arranger.unconsumed[2][:text].should eq("World")
    end

    it "preserves format state across splits" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello\nWorld", [:bold], "FF0000")]
      arranger.unconsumed.each do |hash|
        hash[:styles].should eq([:bold])
        hash[:color].should eq("FF0000")
      end
    end
  end

  describe "#next_string" do
    it "returns the next text string" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello"), ArrangerSpecHelper.make_hash("World")]
      arranger.next_string.should eq("Hello")
      arranger.next_string.should eq("World")
    end

    it "returns nil when exhausted" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello")]
      arranger.next_string.should eq("Hello")
      arranger.next_string.should be_nil
    end

    it "updates current_format_state" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Bold", [:bold], "FF0000")]
      arranger.next_string
      arranger.current_format_state.styles.should eq([:bold])
      arranger.current_format_state.color.should eq("FF0000")
    end
  end

  describe "#preview_next_string" do
    it "peeks without consuming" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello")]
      arranger.preview_next_string.should eq("Hello")
      arranger.preview_next_string.should eq("Hello")
      arranger.finished?.should be_false
    end
  end

  describe "#finished?" do
    it "returns false when unconsumed fragments remain" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello")]
      arranger.finished?.should be_false
    end

    it "returns true when all fragments consumed" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello")]
      arranger.next_string
      arranger.finished?.should be_true
    end
  end

  describe "#update_last_string" do
    it "updates the last consumed fragment" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello World")]
      arranger.next_string
      arranger.update_last_string("Hello", " World")
      arranger.consumed.last[:text].should eq("Hello")
      arranger.unconsumed.first[:text].should eq(" World")
    end

    it "removes consumed entry when printed is empty" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello")]
      arranger.next_string
      arranger.update_last_string("", "Hello")
      arranger.consumed.should be_empty
    end
  end

  describe "#finalize_line" do
    it "creates fragments from consumed hashes" do
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = ArrangerSpecHelper.make_measurer
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello"), ArrangerSpecHelper.make_hash(" World", [:bold])]
      arranger.next_string
      arranger.next_string
      arranger.finalize_line(measurer)
      arranger.finalized?.should be_true
      arranger.fragments.size.should eq(2)
      arranger.fragments[0].text.should eq("Hello")
      arranger.fragments[1].text.should eq(" World")
      arranger.fragments[1].bold?.should be_true
    end

    it "measures fragment widths" do
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = ArrangerSpecHelper.make_measurer
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello")]
      arranger.next_string
      arranger.finalize_line(measurer)
      arranger.fragments[0].width.should be > 0.0
    end

    it "sets line height metrics" do
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = ArrangerSpecHelper.make_measurer
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello")]
      arranger.next_string
      arranger.finalize_line(measurer)
      arranger.max_line_height.should be > 0.0
      arranger.max_ascender.should be > 0.0
      arranger.max_descender.should be > 0.0
    end
  end

  describe "#line" do
    it "returns the concatenated line text" do
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = ArrangerSpecHelper.make_measurer
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello"), ArrangerSpecHelper.make_hash(" World")]
      arranger.next_string
      arranger.next_string
      arranger.finalize_line(measurer)
      arranger.line.should eq("Hello World")
    end

    it "raises when not finalized" do
      arranger = PDF::Text::Formatted::Arranger.new
      arranger.format_array = [ArrangerSpecHelper.make_hash("Hello")]
      expect_raises(Exception) { arranger.line }
    end
  end

  describe "#space_count" do
    it "counts total spaces across fragments" do
      arranger = PDF::Text::Formatted::Arranger.new
      measurer = ArrangerSpecHelper.make_measurer
      arranger.format_array = [ArrangerSpecHelper.make_hash("hello world"), ArrangerSpecHelper.make_hash(" foo bar")]
      arranger.next_string
      arranger.next_string
      arranger.finalize_line(measurer)
      arranger.space_count.should eq(3)
    end
  end
end
