require "../../spec_helper"

describe PDF::SVG::Transform do
  describe ".parse" do
    it "returns identity for nil" do
      PDF::SVG::Transform.parse(nil).should eq(PDF::SVG::Transform::IDENTITY)
    end

    it "returns identity for empty string" do
      PDF::SVG::Transform.parse("").should eq(PDF::SVG::Transform::IDENTITY)
    end

    it "parses translate(tx, ty)" do
      m = PDF::SVG::Transform.parse("translate(10, 20)")
      m[4].should be_close(10.0, 0.001)
      m[5].should be_close(20.0, 0.001)
    end

    it "parses translate(tx) with implicit ty=0" do
      m = PDF::SVG::Transform.parse("translate(10)")
      m[4].should be_close(10.0, 0.001)
      m[5].should be_close(0.0, 0.001)
    end

    it "parses scale(sx, sy)" do
      m = PDF::SVG::Transform.parse("scale(2, 3)")
      m[0].should be_close(2.0, 0.001)
      m[3].should be_close(3.0, 0.001)
    end

    it "parses scale(s) with uniform scaling" do
      m = PDF::SVG::Transform.parse("scale(2)")
      m[0].should be_close(2.0, 0.001)
      m[3].should be_close(2.0, 0.001)
    end

    it "parses rotate(angle)" do
      m = PDF::SVG::Transform.parse("rotate(90)")
      m[0].should be_close(0.0, 0.001)
      m[1].should be_close(1.0, 0.001)
      m[2].should be_close(-1.0, 0.001)
      m[3].should be_close(0.0, 0.001)
    end

    it "parses matrix(a, b, c, d, e, f)" do
      m = PDF::SVG::Transform.parse("matrix(1, 0, 0, 1, 50, 100)")
      m[0].should be_close(1.0, 0.001)
      m[4].should be_close(50.0, 0.001)
      m[5].should be_close(100.0, 0.001)
    end

    it "combines multiple transforms" do
      m = PDF::SVG::Transform.parse("translate(10, 20) scale(2)")
      # translate(10,20) * scale(2) = [2, 0, 0, 2, 10, 20]
      m[0].should be_close(2.0, 0.001)
      m[3].should be_close(2.0, 0.001)
      m[4].should be_close(10.0, 0.001)
      m[5].should be_close(20.0, 0.001)
    end
  end

  describe ".apply" do
    it "applies transformation to a point" do
      m = PDF::SVG::Transform.parse("translate(10, 20)")
      x, y = PDF::SVG::Transform.apply(m, 5.0, 5.0)
      x.should be_close(15.0, 0.001)
      y.should be_close(25.0, 0.001)
    end

    it "applies scale transformation" do
      m = PDF::SVG::Transform.parse("scale(2, 3)")
      x, y = PDF::SVG::Transform.apply(m, 10.0, 10.0)
      x.should be_close(20.0, 0.001)
      y.should be_close(30.0, 0.001)
    end
  end

  describe ".multiply" do
    it "multiplies identity matrices" do
      result = PDF::SVG::Transform.multiply(
        PDF::SVG::Transform::IDENTITY,
        PDF::SVG::Transform::IDENTITY
      )
      result.should eq(PDF::SVG::Transform::IDENTITY)
    end
  end
end
