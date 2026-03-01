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
end
