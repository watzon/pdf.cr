module PDF
  module Text
    module Formatted
      # Flows formatted text through a sequence of boxes. The text that does
      # not fit in one box continues in the next box, which can be on the
      # same page (for example linked columns) or on another page.
      #
      # `Page#formatted_text_flow` and `Document#formatted_text_flow` cover
      # the common cases. Use this class directly to choose each box.
      #
      # ```
      # flow = PDF::Text::Formatted::Flow.new(doc, align: :justify)
      # result = flow.render(fragments) do |index|
      #   next if index >= 2
      #   PDF::Text::Formatted::Flow::Frame.new(page, {50.0 + index * 260, 700.0}, 250.0, 300.0)
      # end
      # result.remaining # => text that did not fit in the two boxes
      # ```
      class Flow
        # A box to render text into: the page, the upper-left corner, the
        # width and the height, in points.
        record Frame, page : Page, at : Tuple(Float64, Float64), width : Float64, height : Float64

        getter align : Symbol
        getter leading : Float64
        getter font_name : String
        getter font_size : Float64
        getter metrics : Symbol

        def initialize(@document : Document, *, @align : Symbol = :left, @leading : Float64 = 0.0,
                       @font_name : String = "Helvetica", @font_size : Float64 = 12.0,
                       @metrics : Symbol = :fixed)
        end

        # Renders the fragments into the frames that the block returns, in
        # order, until all text is printed or the block returns `nil`. The
        # block gets the zero-based index of the frame and the `Box` that was
        # rendered into the previous frame (`nil` for the first frame).
        #
        # Raises `ArgumentError` when the block returns `nil` for the first
        # frame.
        def render(fragments : Array(FragmentHash), & : Int32, Box? -> Frame?) : Result
          remaining = fragments
          index = 0
          line_count = 0
          previous_box : Box? = nil
          last : Tuple(Frame, Box)? = nil

          while frame = yield index, previous_box
            box = Box.new(
              formatted_text: remaining,
              at: frame.at,
              width: frame.width,
              height: frame.height,
              align: @align,
              overflow: :truncate,
              leading: @leading,
              document: @document,
              font_name: @font_name,
              font_size: @font_size,
              metrics: @metrics,
            )
            remaining = box.render(frame.page)
            line_count += box.line_count
            last = {frame, box}
            previous_box = box
            index += 1
            break if remaining.empty?
          end

          frame, box = last || raise ArgumentError.new("Flow needs at least one frame, but the block returned nil for the first frame.")
          Result.new(
            remaining: remaining,
            page: frame.page,
            cursor: box.cursor,
            rendered_height: box.rendered_height,
            box_index: index - 1,
            line_count: line_count,
          )
        end
      end
    end
  end
end
