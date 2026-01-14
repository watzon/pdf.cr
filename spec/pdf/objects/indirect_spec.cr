require "../../spec_helper"

describe PDF::Objects::Indirect do
  describe "#to_pdf" do
    it "serializes with dictionary value" do
      dict = PDF::Objects::Dictionary.new
      dict["Type"] = PDF::Objects::Name.new("Page")

      obj = PDF::Objects::Indirect.new(5, 0, dict)
      pdf = obj.to_pdf

      pdf.should start_with("5 0 obj\n")
      pdf.should end_with("\nendobj")
      pdf.should contain("<</Type /Page>>")
    end

    it "serializes with number value" do
      obj = PDF::Objects::Indirect.new(1, 0, PDF::Objects::Number.new(42))
      obj.to_pdf.should eq("1 0 obj\n42\nendobj")
    end

    it "serializes with array value" do
      arr = PDF::Objects::Array.new([1, 2, 3])
      obj = PDF::Objects::Indirect.new(2, 0, arr)
      obj.to_pdf.should eq("2 0 obj\n[1 2 3]\nendobj")
    end

    it "serializes with non-zero generation" do
      obj = PDF::Objects::Indirect.new(5, 3, PDF::Objects::Number.new(42))
      obj.to_pdf.should start_with("5 3 obj\n")
    end
  end

  describe "initialization" do
    it "accepts two-argument form (defaults generation to 0)" do
      obj = PDF::Objects::Indirect.new(5, PDF::Objects::Number.new(42))
      obj.generation.should eq(0)
    end

    it "raises for zero object number" do
      expect_raises(ArgumentError, "Object number must be positive") do
        PDF::Objects::Indirect.new(0, 0, PDF::Objects::Null.new)
      end
    end

    it "raises for negative object number" do
      expect_raises(ArgumentError, "Object number must be positive") do
        PDF::Objects::Indirect.new(-1, 0, PDF::Objects::Null.new)
      end
    end

    it "raises for negative generation" do
      expect_raises(ArgumentError, "Generation must be non-negative") do
        PDF::Objects::Indirect.new(1, -1, PDF::Objects::Null.new)
      end
    end
  end

  describe "#object_number" do
    it "returns the object number" do
      obj = PDF::Objects::Indirect.new(5, 0, PDF::Objects::Null.new)
      obj.object_number.should eq(5)
    end
  end

  describe "#generation" do
    it "returns the generation number" do
      obj = PDF::Objects::Indirect.new(5, 2, PDF::Objects::Null.new)
      obj.generation.should eq(2)
    end
  end

  describe "#value" do
    it "returns the wrapped value" do
      num = PDF::Objects::Number.new(42)
      obj = PDF::Objects::Indirect.new(5, 0, num)
      obj.value.should eq(num)
    end
  end

  describe "#reference" do
    it "returns a Reference to this object" do
      obj = PDF::Objects::Indirect.new(5, 2, PDF::Objects::Null.new)
      ref = obj.reference

      ref.object_number.should eq(5)
      ref.generation.should eq(2)
      ref.to_pdf.should eq("5 2 R")
    end
  end

  describe "#ref" do
    it "is an alias for reference" do
      obj = PDF::Objects::Indirect.new(5, 0, PDF::Objects::Null.new)
      obj.ref.should eq(obj.reference)
    end
  end

  describe "equality" do
    it "compares by object number, generation, and value" do
      a = PDF::Objects::Indirect.new(5, 0, PDF::Objects::Number.new(42))
      b = PDF::Objects::Indirect.new(5, 0, PDF::Objects::Number.new(42))
      c = PDF::Objects::Indirect.new(5, 0, PDF::Objects::Number.new(99))
      d = PDF::Objects::Indirect.new(6, 0, PDF::Objects::Number.new(42))

      a.should eq(b)
      a.should_not eq(c)
      a.should_not eq(d)
    end
  end
end
