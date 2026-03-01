require "../../../spec_helper"

describe PDF::Text::Formatted::Fragment do
  describe "#initialize" do
    it "creates a fragment with text and default format state" do
      fragment = PDF::Text::Formatted::Fragment.new("Hello")
      fragment.text.should eq("Hello")
      fragment.styles.should be_empty
      fragment.color.should be_nil
      fragment.font.should be_nil
      fragment.size.should be_nil
    end

    it "creates a fragment with custom format state" do
      state = PDF::Text::Formatted::FormatState.new(
        styles: [:bold, :italic],
        color: "FF0000",
        font: "Courier",
        size: 14.0,
      )
      fragment = PDF::Text::Formatted::Fragment.new("World", state)
      fragment.text.should eq("World")
      fragment.styles.should eq([:bold, :italic])
      fragment.color.should eq("FF0000")
      fragment.font.should eq("Courier")
      fragment.size.should eq(14.0)
    end
  end

  describe "#bold?" do
    it "returns true when bold style is present" do
      state = PDF::Text::Formatted::FormatState.new(styles: [:bold])
      fragment = PDF::Text::Formatted::Fragment.new("Bold", state)
      fragment.bold?.should be_true
    end

    it "returns false when bold style is absent" do
      fragment = PDF::Text::Formatted::Fragment.new("Normal")
      fragment.bold?.should be_false
    end
  end

  describe "#italic?" do
    it "returns true when italic style is present" do
      state = PDF::Text::Formatted::FormatState.new(styles: [:italic])
      fragment = PDF::Text::Formatted::Fragment.new("Italic", state)
      fragment.italic?.should be_true
    end

    it "returns false when italic style is absent" do
      fragment = PDF::Text::Formatted::Fragment.new("Normal")
      fragment.italic?.should be_false
    end
  end

  describe "#underline?" do
    it "returns true when underline style is present" do
      state = PDF::Text::Formatted::FormatState.new(styles: [:underline])
      fragment = PDF::Text::Formatted::Fragment.new("Underline", state)
      fragment.underline?.should be_true
    end
  end

  describe "#strikethrough?" do
    it "returns true when strikethrough style is present" do
      state = PDF::Text::Formatted::FormatState.new(styles: [:strikethrough])
      fragment = PDF::Text::Formatted::Fragment.new("Strike", state)
      fragment.strikethrough?.should be_true
    end
  end

  describe "#subscript?" do
    it "returns true when subscript style is present" do
      state = PDF::Text::Formatted::FormatState.new(styles: [:subscript])
      fragment = PDF::Text::Formatted::Fragment.new("Sub", state)
      fragment.subscript?.should be_true
    end
  end

  describe "#superscript?" do
    it "returns true when superscript style is present" do
      state = PDF::Text::Formatted::FormatState.new(styles: [:superscript])
      fragment = PDF::Text::Formatted::Fragment.new("Super", state)
      fragment.superscript?.should be_true
    end
  end

  describe "#space_count" do
    it "counts spaces in the text" do
      fragment = PDF::Text::Formatted::Fragment.new("hello world foo")
      fragment.space_count.should eq(2)
    end

    it "returns 0 for text without spaces" do
      fragment = PDF::Text::Formatted::Fragment.new("hello")
      fragment.space_count.should eq(0)
    end
  end

  describe "#actual_width" do
    it "returns width when word_spacing is 0" do
      fragment = PDF::Text::Formatted::Fragment.new("hello world")
      fragment.width = 100.0
      fragment.actual_width.should eq(100.0)
    end

    it "includes word spacing in width calculation" do
      fragment = PDF::Text::Formatted::Fragment.new("hello world")
      fragment.width = 100.0
      fragment.word_spacing = 5.0
      fragment.actual_width.should eq(105.0) # 100 + 5*1 space
    end
  end

  describe "#height" do
    it "returns ascender + descender" do
      fragment = PDF::Text::Formatted::Fragment.new("test")
      fragment.ascender = 10.0
      fragment.descender = 3.0
      fragment.height.should eq(13.0)
    end
  end

  describe "#y_offset" do
    it "returns 0 for normal text" do
      fragment = PDF::Text::Formatted::Fragment.new("normal")
      fragment.y_offset.should eq(0.0)
    end

    it "returns negative descender for subscript" do
      state = PDF::Text::Formatted::FormatState.new(styles: [:subscript])
      fragment = PDF::Text::Formatted::Fragment.new("sub", state)
      fragment.descender = 3.0
      fragment.y_offset.should eq(-3.0)
    end

    it "returns 0.85 * ascender for superscript" do
      state = PDF::Text::Formatted::FormatState.new(styles: [:superscript])
      fragment = PDF::Text::Formatted::Fragment.new("super", state)
      fragment.ascender = 10.0
      fragment.y_offset.should eq(8.5)
    end
  end

  describe "#top and #bottom" do
    it "calculates top and bottom from baseline" do
      fragment = PDF::Text::Formatted::Fragment.new("test")
      fragment.baseline = 100.0
      fragment.ascender = 10.0
      fragment.descender = 3.0
      fragment.top.should eq(110.0)
      fragment.bottom.should eq(97.0)
    end
  end

  describe "#right" do
    it "calculates right from left and width" do
      fragment = PDF::Text::Formatted::Fragment.new("test")
      fragment.left = 50.0
      fragment.width = 100.0
      fragment.right.should eq(150.0)
    end
  end
end
