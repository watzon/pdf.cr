module PDF
  module Text
    module Formatted
      # The outcome of rendering formatted text: the text that did not fit,
      # and where the text ended.
      #
      # Returned by `Flow#render`, `Page#formatted_text_flow` and
      # `Document#formatted_text_flow`, and yielded by the block form of
      # `Page#formatted_text_box`.
      #
      # ```
      # page.formatted_text_box(fragments, at: {50, 700}, width: 400) do |result|
      #   page.formatted_text_box(more, at: {50, result.cursor - 6}, width: 400)
      # end
      # ```
      struct Result
        # The fragments that did not fit. Empty when all text was printed.
        getter remaining : Array(FragmentHash)

        # The page of the last box that was used.
        getter page : Page

        # The y coordinate below the last rendered line in the last box that
        # was used. Equal to the top of that box when it printed nothing.
        getter cursor : Float64

        # The height used in the last box, see `Box#rendered_height`.
        getter rendered_height : Float64

        # The zero-based index of the last box that was used.
        getter box_index : Int32

        # The total number of rendered lines in all boxes.
        getter line_count : Int32

        def initialize(*, @remaining : Array(FragmentHash), @page : Page, @cursor : Float64,
                       @rendered_height : Float64, @box_index : Int32, @line_count : Int32)
        end

        # Whether all text was printed.
        def everything_printed? : Bool
          @remaining.empty?
        end

        # Whether no line was printed.
        def nothing_printed? : Bool
          @line_count == 0
        end
      end
    end
  end
end
