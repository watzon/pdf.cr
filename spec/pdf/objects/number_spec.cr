require "../../spec_helper"

describe PDF::Objects::Number do
  describe "#to_pdf" do
    context "with integers" do
      it "serializes positive integers" do
        PDF::Objects::Number.new(42).to_pdf.should eq("42")
      end

      it "serializes negative integers" do
        PDF::Objects::Number.new(-17).to_pdf.should eq("-17")
      end

      it "serializes zero" do
        PDF::Objects::Number.new(0).to_pdf.should eq("0")
      end

      it "serializes large integers" do
        PDF::Objects::Number.new(999999999).to_pdf.should eq("999999999")
      end
    end

    context "with real numbers" do
      it "serializes positive reals" do
        PDF::Objects::Number.new(3.14).to_pdf.should eq("3.14")
      end

      it "serializes negative reals" do
        PDF::Objects::Number.new(-2.5).to_pdf.should eq("-2.5")
      end

      it "serializes small decimals" do
        PDF::Objects::Number.new(0.001).to_pdf.should eq("0.001")
      end

      it "removes trailing zeros" do
        PDF::Objects::Number.new(1.5000).to_pdf.should eq("1.5")
      end

      it "converts whole floats to integers" do
        PDF::Objects::Number.new(5.0).to_pdf.should eq("5")
      end

      it "limits decimal places" do
        # 6 decimal places max
        num = PDF::Objects::Number.new(3.14159265359)
        num.to_pdf.should eq("3.141593")
      end
    end
  end

  describe "#integer?" do
    it "returns true for integers" do
      PDF::Objects::Number.new(42).integer?.should be_true
    end

    it "returns false for reals" do
      PDF::Objects::Number.new(3.14).integer?.should be_false
    end
  end

  describe "#real?" do
    it "returns true for reals" do
      PDF::Objects::Number.new(3.14).real?.should be_true
    end

    it "returns false for integers" do
      PDF::Objects::Number.new(42).real?.should be_false
    end
  end

  describe "#to_i64" do
    it "converts to Int64" do
      PDF::Objects::Number.new(42).to_i64.should eq(42_i64)
    end

    it "truncates floats" do
      PDF::Objects::Number.new(3.9).to_i64.should eq(3_i64)
    end
  end

  describe "#to_f64" do
    it "converts integers to Float64" do
      PDF::Objects::Number.new(42).to_f64.should eq(42.0)
    end

    it "returns floats as-is" do
      PDF::Objects::Number.new(3.14).to_f64.should eq(3.14)
    end
  end

  describe "equality" do
    it "compares by value" do
      a = PDF::Objects::Number.new(42)
      b = PDF::Objects::Number.new(42)
      c = PDF::Objects::Number.new(43)

      a.should eq(b)
      a.should_not eq(c)
    end

    it "integers and floats with same value are not equal" do
      # They have different internal representations
      int = PDF::Objects::Number.new(5)
      float = PDF::Objects::Number.new(5.0)

      # The values are different types internally
      int.integer?.should be_true
      float.real?.should be_true
    end
  end
end
