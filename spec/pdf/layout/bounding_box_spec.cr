require "../../spec_helper"

describe PDF::Layout::BoundingBox do
  describe "#initialize" do
    it "creates a bounding box with fixed height" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.x.should eq(50.0)
      box.y.should eq(700.0)
      box.box_width.should eq(400.0)
      box.height.should eq(300.0)
      box.stretchy?.should be_false
    end

    it "creates a stretchy bounding box without height" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0,
      )
      box.stretchy?.should be_true
      box.height.should eq(0.0)
    end
  end

  describe "#cursor" do
    it "starts at the top of the box" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.cursor.should eq(300.0)
    end

    it "decreases when moving down" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.move_down(50.0)
      box.cursor.should eq(250.0)
    end
  end

  describe "#move_down" do
    it "updates the cursor position" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.move_down(100.0)
      box.cursor.should eq(200.0)
    end

    it "stretches a stretchy box" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0,
      )
      box.move_down(50.0)
      box.height.should eq(50.0)
      box.move_down(30.0)
      box.height.should eq(80.0)
    end
  end

  describe "#width" do
    it "returns box_width when no padding" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.width.should eq(400.0)
    end

    it "subtracts padding from width" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.add_left_padding(20.0)
      box.add_right_padding(10.0)
      # add_left_padding reduces box_width by 20 -> 380
      # add_right_padding reduces box_width by 10 -> 370
      # width returns @box_width = 370
      box.width.should eq(370.0)
    end
  end

  describe "#indent" do
    it "temporarily adjusts padding" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.indent(20.0, 10.0) do
        # add_left_padding: box_width -= 20 -> 380
        # add_right_padding: box_width -= 10 -> 370
        box.width.should eq(370.0)
        box.total_left_padding.should eq(20.0)
        box.total_right_padding.should eq(10.0)
      end
      # After indent: subtract restores box_width
      box.width.should eq(400.0)
      box.total_left_padding.should eq(0.0)
      box.total_right_padding.should eq(0.0)
    end
  end

  describe "relative coordinates" do
    it "returns correct relative positions" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.left.should eq(0.0)
      box.right.should eq(400.0)
      box.top.should eq(300.0)
      box.bottom.should eq(0.0)
    end

    it "returns correct corner points" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.top_left.should eq({0.0, 300.0})
      box.top_right.should eq({400.0, 300.0})
      box.bottom_left.should eq({0.0, 0.0})
      box.bottom_right.should eq({400.0, 0.0})
    end
  end

  describe "absolute coordinates" do
    it "returns correct absolute positions" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.absolute_left.should eq(50.0)
      box.absolute_right.should eq(450.0)
      box.absolute_top.should eq(700.0)
      box.absolute_bottom.should eq(400.0)
    end

    it "returns correct absolute positions after padding" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.add_left_padding(20.0)
      # x moved to 70, box_width reduced to 380
      box.absolute_left.should eq(70.0)
      box.absolute_right.should eq(450.0) # 70 + 380
    end

    it "returns correct absolute corner points" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.absolute_top_left.should eq({50.0, 700.0})
      box.absolute_top_right.should eq({450.0, 700.0})
      box.absolute_bottom_left.should eq({50.0, 400.0})
      box.absolute_bottom_right.should eq({450.0, 400.0})
    end
  end

  describe "#anchor" do
    it "returns the bottom-left corner" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.anchor.should eq({50.0, 400.0})
    end
  end

  describe "#to_absolute" do
    it "converts relative to absolute coordinates" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.to_absolute({10.0, 20.0}).should eq({60.0, 680.0})
    end
  end

  describe "#absolute_cursor_y" do
    it "returns the absolute y position of the cursor" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.absolute_cursor_y.should eq(700.0)
      box.move_down(50.0)
      box.absolute_cursor_y.should eq(650.0)
    end
  end

  describe "padding operations" do
    it "adds and subtracts left padding" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.add_left_padding(20.0)
      box.x.should eq(70.0)
      box.box_width.should eq(380.0)
      box.total_left_padding.should eq(20.0)

      box.subtract_left_padding(20.0)
      box.x.should eq(50.0)
      box.box_width.should eq(400.0)
      box.total_left_padding.should eq(0.0)
    end

    it "adds and subtracts right padding" do
      box = PDF::Layout::BoundingBox.new(
        x: 50.0, y: 700.0, box_width: 400.0, fixed_height: 300.0,
      )
      box.add_right_padding(30.0)
      box.box_width.should eq(370.0)
      box.total_right_padding.should eq(30.0)

      box.subtract_right_padding(30.0)
      box.box_width.should eq(400.0)
      box.total_right_padding.should eq(0.0)
    end
  end
end
