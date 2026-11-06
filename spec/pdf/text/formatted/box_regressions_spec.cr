require "../../../spec_helper"

private def new_page : PDF::Page
  doc = PDF::Document.new
  page_ref : PDF::Page? = nil
  doc.page do |current_page|
    current_page.font("Helvetica", size: 12)
    page_ref = current_page
  end
  page_ref || raise("page not created")
end

private def new_doc_and_page : Tuple(PDF::Document, PDF::Page)
  doc = PDF::Document.new
  page_ref : PDF::Page? = nil
  doc.page do |current_page|
    current_page.font("Helvetica", size: 12)
    page_ref = current_page
  end
  {doc, page_ref || raise("page not created")}
end

private def frag(text : String, size : Float64? = nil, color : String? = nil) : PDF::Text::Formatted::FragmentHash
  hash = PDF::Text::Formatted::FragmentHash.new
  hash[:text] = text
  hash[:styles] = [] of Symbol
  hash[:size] = size if size
  hash[:color] = color if color
  hash
end

private def make_box(text : String, doc : PDF::Document, **opts)
  PDF::Text::Formatted::Box.new(
    formatted_text: [frag(text)],
    at: {50.0, 700.0},
    width: opts[:width]? || 400.0,
    height: opts[:height]? || Float64::MAX,
    align: opts[:align]? || :left,
    overflow: opts[:overflow]? || :truncate,
    document: doc,
  )
end

describe "formatted text box fixes" do
  it "accepts the documented named tuple literal" do
    page = new_page
    remaining = page.formatted_text_box(
      [
        {text: "Hello ", styles: [] of Symbol},
        {text: "world", styles: [:bold]},
        {text: "!", styles: [:italic], color: "FF0000"},
      ],
      at: {50, 700},
      width: 400,
      height: 200,
      align: :justify,
      overflow: :truncate,
    )
    remaining.should be_empty
    page.content_string.should contain("(world) Tj")
    page.content_string.should contain("1 0 0 rg")
  end

  describe "overflow" do
    long = "The quick brown fox jumps over the lazy dog. " * 6

    it "truncates by default and returns the remaining text" do
      doc, page = new_doc_and_page
      box = make_box(long, doc, width: 100.0, height: 30.0)
      box.render(page).should_not be_empty
      box.everything_printed?.should be_false
    end

    it "expands past the height limit with :expand" do
      doc, page = new_doc_and_page
      box = make_box(long, doc, width: 100.0, height: 30.0, overflow: :expand)
      box.render(page).should be_empty
      box.everything_printed?.should be_true
      box.rendered_height.should be > 30.0
    end

    it "shrinks text to fit with :shrink_to_fit" do
      doc, page = new_doc_and_page
      text = "The quick brown fox jumps over the lazy dog."
      box = make_box(text, doc, width: 100.0, height: 40.0, overflow: :shrink_to_fit)
      box.render(page).should be_empty
      box.rendered_height.should be <= 40.0
      # font size was reduced below the 12pt default
      page.content_string.scan(/\/\S+ ([\d.]+) Tf/).min_of(&.[1].to_f).should be < 12.0
    end

    it "scales fragments that set their own size when shrinking" do
      doc, page = new_doc_and_page
      box = PDF::Text::Formatted::Box.new(
        formatted_text: [frag("The quick brown fox jumps over the lazy dog. " * 3, size: 20.0)],
        at: {50.0, 700.0}, width: 100.0, height: 60.0, overflow: :shrink_to_fit, document: doc,
      )
      box.render(page).should be_empty
      box.rendered_height.should be <= 60.0
    end

    it "does not shrink below the minimum size" do
      doc, page = new_doc_and_page
      box = make_box(long * 10, doc, width: 50.0, height: 10.0, overflow: :shrink_to_fit)
      box.render(page).should_not be_empty
      page.content_string.scan(/\/\S+ ([\d.]+) Tf/).min_of(&.[1].to_f).should eq(5.0)
    end

    it "reports dry_run results for :shrink_to_fit" do
      doc, _ = new_doc_and_page
      box = make_box("The quick brown fox jumps over the lazy dog.", doc, width: 100.0, height: 40.0, overflow: :shrink_to_fit)
      height, remaining = box.dry_run
      remaining.should be_empty
      height.should be <= 40.0
    end

    it "raises ArgumentError for an unknown overflow mode" do
      doc, _ = new_doc_and_page
      expect_raises(ArgumentError, /overflow/) { make_box("x", doc, overflow: :bogus) }
    end
  end

  it "terminates when the width is narrower than one character" do
    page = new_page
    remaining = page.formatted_text_box([{text: "hello world", styles: [] of Symbol}], at: {50, 700}, width: 1)
    remaining.should be_empty
  end

  it "terminates in dry_run when the width is narrower than one character" do
    doc, _ = new_doc_and_page
    box = make_box("hello world", doc, width: 1.0)
    _, remaining = box.dry_run
    remaining.should be_empty
  end

  it "keeps consecutive newlines as blank lines" do
    doc, page = new_doc_and_page
    one = make_box("a\nb", doc)
    one.render(page)
    three = make_box("a\n\n\nb", doc)
    three.render(page)
    pitch = 12.0 * 1.2
    (three.rendered_height - one.rendered_height).should be_close(2 * pitch, 0.001)
  end

  it "justifies wrapped lines flush with the right edge" do
    doc, page = new_doc_and_page
    box = make_box("aaa bbb ccc ddd eee fff ggg hhh iii jjj kkk", doc, width: 100.0, align: :justify)
    box.render(page)

    ops = page.content_string.scan(/([\d.\-]+) ([\d.\-]+) Td\n\((\w+)\) Tj/).map { |match| {match[1].to_f, match[2].to_f, match[3]} }
    first_y = ops.first[1]
    first_line = ops.select { |op| (op[1] - first_y).abs < 0.001 }
    first_line.size.should be > 1
    last_x, _, last_word = first_line.last
    font = doc.font("Helvetica")
    (last_x + font.string_width(last_word, 12.0)).should be_close(150.0, 0.01)
  end

  describe "hex colors" do
    it "accepts RGB, RRGGBB, and a leading #" do
      doc, page = new_doc_and_page
      ["F00", "#F00", "FF0000", "#ff0000"].each do |hex|
        box = PDF::Text::Formatted::Box.new(
          formatted_text: [frag("x", color: hex)], at: {50.0, 700.0}, width: 100.0, document: doc)
        box.render(page).should be_empty
      end
    end

    it "raises ArgumentError for non-hex characters" do
      page = new_page
      expect_raises(ArgumentError, /Invalid hex color/) do
        page.formatted_text_box([{text: "x", styles: [] of Symbol, color: "ZZZZZZ"}], at: {50, 700}, width: 100)
      end
    end

    it "raises ArgumentError for a wrong length" do
      page = new_page
      expect_raises(ArgumentError, /Invalid hex color/) do
        page.formatted_text_box([{text: "x", styles: [] of Symbol, color: "FF00"}], at: {50, 700}, width: 100)
      end
    end
  end
end
