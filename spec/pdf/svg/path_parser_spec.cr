require "../../spec_helper"

describe PDF::SVG::PathParser do
  describe ".parse" do
    it "parses moveto and lineto" do
      cmds = PDF::SVG::PathParser.parse("M 10 20 L 30 40")
      cmds.size.should eq(2)
      cmds[0].type.should eq('M')
      cmds[0].args.should eq([10.0, 20.0])
      cmds[1].type.should eq('L')
      cmds[1].args.should eq([30.0, 40.0])
    end

    it "parses relative moveto and lineto" do
      cmds = PDF::SVG::PathParser.parse("m 10 20 l 5 5")
      cmds.size.should eq(2)
      cmds[0].type.should eq('M')
      cmds[0].args.should eq([10.0, 20.0])
      cmds[1].type.should eq('L')
      cmds[1].args.should eq([15.0, 25.0])
    end

    it "parses horizontal and vertical lines" do
      cmds = PDF::SVG::PathParser.parse("M 0 0 H 50 V 30")
      cmds.size.should eq(3)
      cmds[1].type.should eq('L')
      cmds[1].args.should eq([50.0, 0.0])
      cmds[2].type.should eq('L')
      cmds[2].args.should eq([50.0, 30.0])
    end

    it "parses cubic bezier curves" do
      cmds = PDF::SVG::PathParser.parse("M 0 0 C 10 20 30 40 50 60")
      cmds.size.should eq(2)
      cmds[1].type.should eq('C')
      cmds[1].args.should eq([10.0, 20.0, 30.0, 40.0, 50.0, 60.0])
    end

    it "parses close path" do
      cmds = PDF::SVG::PathParser.parse("M 0 0 L 50 0 L 50 50 Z")
      cmds.size.should eq(4)
      cmds[3].type.should eq('Z')
    end

    it "handles empty path data" do
      cmds = PDF::SVG::PathParser.parse("")
      cmds.should be_empty
    end

    it "parses compact notation without spaces" do
      cmds = PDF::SVG::PathParser.parse("M10,20L30,40")
      cmds.size.should eq(2)
      cmds[0].args.should eq([10.0, 20.0])
      cmds[1].args.should eq([30.0, 40.0])
    end

    it "parses negative coordinates" do
      cmds = PDF::SVG::PathParser.parse("M -10 -20 L -30 -40")
      cmds.size.should eq(2)
      cmds[0].args.should eq([-10.0, -20.0])
      cmds[1].args.should eq([-30.0, -40.0])
    end

    it "parses quadratic bezier (converts to cubic)" do
      cmds = PDF::SVG::PathParser.parse("M 0 0 Q 50 50 100 0")
      cmds.size.should eq(2)
      cmds[1].type.should eq('C') # converted to cubic
      cmds[1].args.size.should eq(6)
    end

    it "parses smooth cubic bezier" do
      cmds = PDF::SVG::PathParser.parse("M 0 0 C 10 20 30 40 50 50 S 70 80 90 90")
      cmds.size.should eq(3)
      cmds[2].type.should eq('C')
      cmds[2].args.size.should eq(6)
    end

    it "parses implicit lineto after moveto" do
      cmds = PDF::SVG::PathParser.parse("M 0 0 10 20 30 40")
      cmds.size.should eq(3)
      cmds[0].type.should eq('M')
      cmds[1].type.should eq('L') # implicit lineto
      cmds[2].type.should eq('L')
    end
  end

  describe "number grammar and robustness" do
    it "tokenizes leading-dot numbers" do
      cmds = PDF::SVG::PathParser.parse("M.5 .5")
      cmds.map(&.args).should eq([[0.5, 0.5]])
    end

    it "splits 0.5.5 into 0.5 and .5" do
      cmds = PDF::SVG::PathParser.parse("M0 0 L 0.5.5 3 3")
      cmds[1].args.should eq([0.5, 0.5])
      cmds[2].args.should eq([3.0, 3.0])
    end

    it "splits -.5.5 into -0.5 and .5" do
      cmds = PDF::SVG::PathParser.parse("M0 0 L-.5.5 3 3")
      cmds[1].args.should eq([-0.5, 0.5])
    end

    it "splits 10-5 into 10 and -5" do
      PDF::SVG::PathParser.parse("M10-5")[0].args.should eq([10.0, -5.0])
    end

    it "parses exponents" do
      PDF::SVG::PathParser.parse("M1e-3 2E2")[0].args.should eq([0.001, 200.0])
    end

    it "parses compact arc flags" do
      cmds = PDF::SVG::PathParser.parse("M0 0 a1 1 0 11 5 5")
      cmds.last.args[4..5].should eq([5.0, 5.0])
      cmds.size.should be >= 2
      cmds.all? { |cmd| cmd.type == 'M' || cmd.type == 'C' }.should be_true
    end

    it "terminates on malformed input" do
      [
        "M0 0 L5 5 Z 5", "M.5 .5", "M0 0 L.", "M - - 5", "M 1e", "L 1 2", "5 5 5", "M0 0 Z 1 2 3 L 4 4",
        "M 0 0 A 1 1 0 2 2 5 5", "M0 0 .", "M0 0 ..", "M0 0 L 1 1 x 5 5", "---", "M0 0 ,,, ,", "\u0000M 1 2",
        "M0 0 C 1 2 3", "M 0 0 a", "z z z",
      ].each do |path|
        PDF::SVG::PathParser.parse(path) # must return, not hang
      end
    end

    it "stops parsing at numbers after Z" do
      cmds = PDF::SVG::PathParser.parse("M0 0 L5 5 Z 5")
      cmds.map(&.type).should eq(['M', 'L', 'Z'])
    end

    it "does not emit a spurious command when the next token is a letter" do
      cmds = PDF::SVG::PathParser.parse("M0 0 L 1 1 L")
      cmds.map(&.type).should eq(['M', 'L'])
      cmds[1].args.should eq([1.0, 1.0])
    end
  end

  describe "smooth curve reflection" do
    it "reflects the previous control point after Q for T" do
      cmds = PDF::SVG::PathParser.parse("M0 0 Q 5 5 10 0 T 20 0")
      # reflected control = (15, -5); cubic cp1 = 10 + 2/3*(15-10)
      cmds[2].args[0].should be_close(10 + 10.0 / 3, 1e-9)
      cmds[2].args[1].should be_close(-10.0 / 3, 1e-9)
    end

    it "uses the current point for S when the previous command was not C or S" do
      cmds = PDF::SVG::PathParser.parse("M0 0 Q 5 5 10 0 S 20 20 30 0")
      cmds[2].args[0..1].should eq([10.0, 0.0])
    end

    it "uses the current point for T when the previous command was not Q or T" do
      cmds = PDF::SVG::PathParser.parse("M0 0 C 1 1 2 2 10 0 T 20 0")
      # control = current point (10, 0): cp1 = (10, 0)
      cmds[2].args[0..1].should eq([10.0, 0.0])
    end

    it "reflects for S after C" do
      cmds = PDF::SVG::PathParser.parse("M0 0 C 0 5 5 5 10 0 S 20 5 30 0")
      cmds[2].args[0..1].should eq([15.0, -5.0])
    end
  end

  describe "arcs" do
    it "approximates a half circle with sweep=1 over the top (y negative)" do
      cmds = PDF::SVG::PathParser.parse("M0 0 A 10 10 0 0 1 20 0")
      cmds.size.should eq(3)
      cmds[1..].each(&.type.should(eq('C')))
      cmds[1].args[4].should be_close(10.0, 1e-6)
      cmds[1].args[5].should be_close(-10.0, 1e-6)
      cmds[2].args[4..5].should eq([20.0, 0.0])
    end

    it "uses the other side for sweep=0" do
      cmds = PDF::SVG::PathParser.parse("M0 0 A 10 10 0 0 0 20 0")
      cmds[1].args[4].should be_close(10.0, 1e-6)
      cmds[1].args[5].should be_close(10.0, 1e-6)
    end

    it "scales radii up when too small" do
      cmds = PDF::SVG::PathParser.parse("M0 0 A 1 1 0 0 1 20 0")
      cmds[1].args[5].should be_close(-10.0, 1e-6)
      cmds.last.args[4..5].should eq([20.0, 0.0])
    end

    it "falls back to a line when a radius is zero" do
      cmds = PDF::SVG::PathParser.parse("M0 0 A 0 10 0 0 1 20 5")
      cmds.map(&.type).should eq(['M', 'L'])
      cmds[1].args.should eq([20.0, 5.0])
    end
  end
end
