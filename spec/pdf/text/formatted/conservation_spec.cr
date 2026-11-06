require "../../../spec_helper"

# Checks that line wrapping keeps all text: the wrapped lines and the
# remaining fragments contain every character of the input, in order and with
# its format. Only whitespace at the start of a line can be left out.
#
# A check that only compares the remaining text with a suffix of the input
# cannot find characters that are lost or added on a printed line.
private alias Cell = Tuple(Char, Array(Symbol), String?, Float64?)

private LINE_BREAK = '\u0000'

private def cells(fragments : Array(PDF::Text::Formatted::FragmentHash)) : Array(Cell)
  result = [] of Cell
  fragments.each do |hash|
    styles = (hash[:styles]?.try(&.as(Array(Symbol))) || [] of Symbol).sort
    hash[:text].as(String).each_char do |char|
      result << {char, styles, hash[:color]?.as(String?), hash[:size]?.as(Float64?)}
    end
  end
  result
end

# Wraps all lines and returns the printed cells (with a LINE_BREAK cell after
# each line) and the cells of the text that could not be placed.
private def wrap(document : PDF::Document, fragments : Array(PDF::Text::Formatted::FragmentHash),
                 width : Float64) : Tuple(Array(Cell), Array(Cell))
  measurer = PDF::Text::Formatted::FontMeasurer.new(document)
  arranger = PDF::Text::Formatted::Arranger.new
  line_wrap = PDF::Text::Formatted::LineWrap.new
  arranger.format_array = fragments
  printed = [] of Cell
  1000.times do
    line_wrap.wrap_line(arranger: arranger, width: width, font_measurer: measurer)
    if arranger.consumed.empty? && !line_wrap.newline_encountered? && !arranger.finished?
      arranger.repack_unretrieved
      break
    end
    arranger.fragments.each do |fragment|
      state = fragment.format_state
      fragment.text.each_char { |char| printed << {char, state.styles.sort, state.color, state.size} }
    end
    printed << {'\n', [] of Symbol, nil, nil} if line_wrap.newline_encountered?
    printed << {LINE_BREAK, [] of Symbol, nil, nil}
    break if arranger.finished?
  end
  {printed, cells(arranger.unconsumed)}
end

private def same?(expected : Cell, actual : Cell) : Bool
  # A newline cell has no format.
  expected == actual || (expected[0] == '\n' && actual[0] == '\n')
end

# Returns nil when the output conserves the input, or a description of the
# first difference.
private def conservation_error(input : Array(Cell), output : Array(Cell)) : String?
  index = 0
  at_line_start = true
  output.each do |cell|
    if cell[0] == LINE_BREAK
      at_line_start = true
      next
    end
    while index < input.size && !same?(input[index], cell)
      unless at_line_start && input[index][0].whitespace?
        return "lost #{input[index].inspect} at #{index}, next output #{cell.inspect}"
      end
      index += 1
    end
    return "added #{cell.inspect}" if index >= input.size
    at_line_start = false unless cell[0].whitespace?
    index += 1
  end
  input[index..].find { |cell| !cell[0].whitespace? }.try { |cell| "lost #{cell.inspect} at the end" }
end

private WORDS  = ["a", "bb", "ccc", "dddd", "supercalifragilistic", "x-y", "H", "2", " ", "  ", "\t", "\n", "\n\n", "é"]
private STYLES = [[] of Symbol, [:bold], [:italic], [:bold, :italic], [:subscript], [:superscript], [:underline]]

private def random_fragments(random : Random) : Array(PDF::Text::Formatted::FragmentHash)
  Array.new(random.rand(1..12)) do
    hash = PDF::Text::Formatted::FragmentHash.new
    hash[:text] = String.build { |io| random.rand(1..6).times { io << WORDS.sample(random) } }
    hash[:styles] = STYLES.sample(random)
    hash[:color] = "FF0000" if random.rand(4) == 0
    hash[:size] = [8.0, 14.0, 20.0].sample(random) if random.rand(4) == 0
    hash
  end
end

describe "formatted text conservation" do
  it "keeps every character of 400 random inputs, in order and with its format" do
    document = PDF::Document.new
    random = Random.new(20_261_105)
    failures = [] of String
    400.times do |number|
      fragments = random_fragments(random)
      width = [5.0, 20.0, 40.0, 80.0, 150.0, 400.0].sample(random)
      printed, remaining = wrap(document, fragments, width)
      if error = conservation_error(cells(fragments), printed + [{LINE_BREAK, [] of Symbol, nil, nil}] + remaining)
        failures << "case #{number} (width #{width}): #{error}"
      end
    end
    failures.should be_empty
  end

  it "keeps the characters after repeated spaces when a line breaks" do
    doc = PDF::Document.new
    remaining = [] of PDF::Text::Formatted::FragmentHash
    doc.page do |page|
      remaining = page.formatted_text_box("aaaa  bbbb  cccc  dddd", at: {0, 700}, width: 60, height: 14)
    end
    # The tokenizer emitted each run of spaces twice, so the remaining text
    # started at "bbb" and one "b" was lost.
    remaining.map(&.[:text].as(String)).join.should eq("bbbb  cccc  dddd")
  end
end
