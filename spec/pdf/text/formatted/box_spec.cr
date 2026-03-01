require "../../../spec_helper"

module BoxSpecHelper
  def self.make_hash(text : String, styles : Array(Symbol) = [] of Symbol, color : String? = nil, font : String? = nil, size : Float64? = nil) : PDF::Text::Formatted::FragmentHash
    hash = PDF::Text::Formatted::FragmentHash.new
    hash[:text] = text
    hash[:styles] = styles
    hash[:color] = color if color
    hash[:font] = font if font
    hash[:size] = size if size
    hash
  end

  def self.make_doc_and_page : Tuple(PDF::Document, PDF::Page)
    doc = PDF::Document.new
    page_ref : PDF::Page? = nil
    doc.page do |p|
      p.font("Helvetica", size: 12)
      page_ref = p
    end
    {doc, page_ref.not_nil!}
  end
end

describe PDF::Text::Formatted::Box do
  describe "#render" do
    it "renders simple text" do
      doc, page = BoxSpecHelper.make_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash("Hello World")],
        at: {50.0, 700.0},
        width: 400.0,
        height: 200.0,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
      box.everything_printed?.should be_true
      box.nothing_printed?.should be_false
    end

    it "renders multiple styled fragments" do
      doc, page = BoxSpecHelper.make_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [
          BoxSpecHelper.make_hash("Hello ", [] of Symbol),
          BoxSpecHelper.make_hash("bold", [:bold]),
          BoxSpecHelper.make_hash(" and ", [] of Symbol),
          BoxSpecHelper.make_hash("italic", [:italic]),
        ],
        at: {50.0, 700.0},
        width: 400.0,
        height: 200.0,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
      box.everything_printed?.should be_true
    end

    it "renders colored text" do
      doc, page = BoxSpecHelper.make_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [
          BoxSpecHelper.make_hash("Red text", [] of Symbol, "FF0000"),
          BoxSpecHelper.make_hash(" Blue text", [] of Symbol, "0000FF"),
        ],
        at: {50.0, 700.0},
        width: 400.0,
        height: 200.0,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
    end

    it "wraps text to multiple lines" do
      doc, page = BoxSpecHelper.make_doc_and_page
      long_text = "This is a long text that should wrap to multiple lines when rendered in a narrow box. " * 3
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash(long_text)],
        at: {50.0, 700.0},
        width: 200.0,
        height: 500.0,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
      box.rendered_height.should be > 14.0
    end

    it "truncates text that exceeds the box height" do
      doc, page = BoxSpecHelper.make_doc_and_page
      long_text = "Line of text. " * 50
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash(long_text)],
        at: {50.0, 700.0},
        width: 200.0,
        height: 30.0,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should_not be_empty
      box.everything_printed?.should be_false
    end

    it "respects left alignment" do
      doc, page = BoxSpecHelper.make_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash("Left aligned")],
        at: {50.0, 700.0},
        width: 400.0,
        height: 200.0,
        align: :left,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
    end

    it "respects center alignment" do
      doc, page = BoxSpecHelper.make_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash("Center aligned")],
        at: {50.0, 700.0},
        width: 400.0,
        height: 200.0,
        align: :center,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
    end

    it "respects right alignment" do
      doc, page = BoxSpecHelper.make_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash("Right aligned")],
        at: {50.0, 700.0},
        width: 400.0,
        height: 200.0,
        align: :right,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
    end

    it "handles justify alignment" do
      doc, page = BoxSpecHelper.make_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash("This text should be justified across the full width of the box when there are multiple words on a line.")],
        at: {50.0, 700.0},
        width: 300.0,
        height: 200.0,
        align: :justify,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
    end

    it "handles text with newlines" do
      doc, page = BoxSpecHelper.make_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash("Line 1\nLine 2\nLine 3")],
        at: {50.0, 700.0},
        width: 400.0,
        height: 200.0,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
    end

    it "handles empty text" do
      doc, page = BoxSpecHelper.make_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash("")],
        at: {50.0, 700.0},
        width: 400.0,
        height: 200.0,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
    end

    it "handles mixed font sizes" do
      doc, page = BoxSpecHelper.make_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [
          BoxSpecHelper.make_hash("Normal ", [] of Symbol, nil, nil, 12.0),
          BoxSpecHelper.make_hash("Large ", [] of Symbol, nil, nil, 24.0),
          BoxSpecHelper.make_hash("Small", [] of Symbol, nil, nil, 8.0),
        ],
        at: {50.0, 700.0},
        width: 400.0,
        height: 200.0,
        document: doc,
      )
      remaining = box.render(page)
      remaining.should be_empty
    end
  end

  describe "#dry_run" do
    it "calculates height without drawing" do
      doc = PDF::Document.new
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash("Hello World\nSecond line\nThird line")],
        at: {50.0, 700.0},
        width: 400.0,
        height: 200.0,
        document: doc,
      )
      height, remaining = box.dry_run
      height.should be > 0.0
      remaining.should be_empty
    end

    it "returns remaining text for overflow" do
      doc = PDF::Document.new
      long_text = "Line of text. " * 50
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [BoxSpecHelper.make_hash(long_text)],
        at: {50.0, 700.0},
        width: 200.0,
        height: 30.0,
        document: doc,
      )
      height, remaining = box.dry_run
      remaining.should_not be_empty
    end
  end
end

describe PDF::Page do
  describe "#formatted_text_box" do
    it "renders formatted text on a page via convenience method" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        remaining = page.formatted_text_box(
          [
            BoxSpecHelper.make_hash("Hello "),
            BoxSpecHelper.make_hash("world", [:bold]),
            BoxSpecHelper.make_hash("!", [:italic], "FF0000"),
          ],
          at: {50, 700},
          width: 400,
          height: 200,
        )
        remaining.should be_empty
      end

      io = IO::Memory.new
      doc.write(io)
      io.size.should be > 0
    end

    it "returns overflow text via convenience method" do
      doc = PDF::Document.new
      doc.page do |page|
        page.font("Helvetica", size: 12)
        long_text = "This is a very long text that will not fit. " * 20
        remaining = page.formatted_text_box(
          [BoxSpecHelper.make_hash(long_text)],
          at: {50, 700},
          width: 200,
          height: 30,
        )
        remaining.should_not be_empty
      end
    end
  end
end
