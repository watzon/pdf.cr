require "../../spec_helper"

describe PDF::Layout::ColumnBox do
  describe "#initialize" do
    it "creates a column box with default settings" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
      )
      box.columns.should eq(2)
      box.spacer.should eq(12.0)
      box.current_column.should eq(0)
    end

    it "creates a column box with custom settings" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 3, spacer: 20.0,
      )
      box.columns.should eq(3)
      box.spacer.should eq(20.0)
    end
  end

  describe "#bare_column_width" do
    it "calculates correct column width for 2 columns" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      # (500 - 20*1) / 2 = 240
      box.bare_column_width.should eq(240.0)
    end

    it "calculates correct column width for 3 columns" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 3, spacer: 10.0,
      )
      # (500 - 10*2) / 3 = 160
      box.bare_column_width.should eq(160.0)
    end
  end

  describe "#width" do
    it "returns column width minus padding" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.width.should eq(240.0)
    end

    it "accounts for padding" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.add_left_padding(10.0)
      box.add_right_padding(10.0)
      # box_width reduced by 20 -> 480
      # bare_column_width = (480 - 20) / 2 = 230
      # width = 230 - (10 + 10) = 210
      box.width.should eq(210.0)
    end
  end

  describe "#width_of_column" do
    it "returns column width plus spacer" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      # 240 + 20 = 260
      box.width_of_column.should eq(260.0)
    end
  end

  describe "#left_side and #right_side" do
    it "returns correct positions for first column" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.left_side.should eq(50.0)
      # absolute_right = x + box_width = 50 + 500 = 550
      # columns_from_right = 2 - 1 - 0 = 1
      # right_side = 550 - 260*1 = 290
      box.right_side.should eq(290.0)
    end

    it "returns correct positions for second column" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.advance_column
      # left_side = 50 + 260*1 = 310
      box.left_side.should eq(310.0)
      # columns_from_right = 2 - 1 - 1 = 0
      # right_side = 550 - 260*0 = 550
      box.right_side.should eq(550.0)
    end
  end

  describe "#left and #right" do
    it "returns relative positions for first column" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.left.should eq(0.0)
      box.right.should eq(240.0)
    end

    it "returns relative positions for second column" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.advance_column
      box.left.should eq(260.0)
      box.right.should eq(500.0)
    end
  end

  describe "#advance_column" do
    it "moves to the next column" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.current_column.should eq(0)
      needs_new_page = box.advance_column
      needs_new_page.should be_false
      box.current_column.should eq(1)
    end

    it "wraps around and signals new page needed" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.advance_column  # column 0 -> 1
      needs_new_page = box.advance_column  # column 1 -> 0 (wrap)
      needs_new_page.should be_true
      box.current_column.should eq(0)
    end

    it "resets cursor on column advance" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.move_down(100.0)
      box.cursor.should eq(500.0)
      box.advance_column
      box.cursor.should eq(600.0) # cursor reset to top
    end
  end

  describe "#to_absolute" do
    it "converts relative to absolute for first column" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.to_absolute({10.0, 20.0}).should eq({60.0, 680.0})
    end

    it "converts relative to absolute for second column" do
      box = PDF::Layout::ColumnBox.new(
        x: 50.0, y: 700.0, width: 500.0, height: 600.0,
        columns: 2, spacer: 20.0,
      )
      box.advance_column
      box.to_absolute({10.0, 20.0}).should eq({320.0, 680.0})
    end
  end
end
