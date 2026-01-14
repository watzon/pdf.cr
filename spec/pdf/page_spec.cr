require "../spec_helper"

describe PDF::Page do
  describe "initialization" do
    it "creates page with default size" do
      doc = PDF::Document.new
      page = PDF::Page.new(doc)
      page.width.should eq(612.0)
      page.height.should eq(792.0)
    end

    it "creates page with custom size" do
      doc = PDF::Document.new
      page = PDF::Page.new(doc, 400.0, 600.0)
      page.width.should eq(400.0)
      page.height.should eq(600.0)
    end
  end

  describe "#font" do
    it "sets current font" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.font("Helvetica", size: 14)
        result.should be(page) # Returns self for chaining
      end
    end
  end

  describe "#text" do
    it "raises if no font is set" do
      doc = PDF::Document.new
      doc.page do |page|
        expect_raises(Exception, /No font set/) do
          page.text("Hello", at: {72, 720})
        end
      end
    end

    it "returns self for chaining" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        result = page.text("Hello", at: {72, 720})
        result.should be(page)
      end
    end
  end

  describe "graphics operations" do
    it "supports stroke_color" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.stroke_color(1.0, 0.0, 0.0)
        result.should be(page)
      end
    end

    it "supports fill_color" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.fill_color(0.0, 0.0, 1.0)
        result.should be(page)
      end
    end

    it "supports line_width" do
      doc = PDF::Document.new
      doc.page do |page|
        result = page.line_width(2)
        result.should be(page)
      end
    end

    it "supports move_to and line_to" do
      doc = PDF::Document.new
      doc.page do |page|
        page.move_to(0, 0).line_to(100, 100).stroke
      end
    end

    it "supports rectangle" do
      doc = PDF::Document.new
      doc.page do |page|
        page.rectangle(10, 10, 50, 50).fill
      end
    end

    it "supports save_graphics_state with block" do
      doc = PDF::Document.new
      doc.page do |page|
        block_executed = false
        page.save_graphics_state do
          block_executed = true
        end
        block_executed.should be_true
      end
    end
  end
end
