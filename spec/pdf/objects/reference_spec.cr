require "../../spec_helper"

describe PDF::Objects::Reference do
  describe "#to_pdf" do
    it "serializes with generation 0" do
      ref = PDF::Objects::Reference.new(5, 0)
      ref.to_pdf.should eq("5 0 R")
    end

    it "serializes with non-zero generation" do
      ref = PDF::Objects::Reference.new(5, 2)
      ref.to_pdf.should eq("5 2 R")
    end

    it "serializes large object numbers" do
      ref = PDF::Objects::Reference.new(99999, 0)
      ref.to_pdf.should eq("99999 0 R")
    end
  end

  describe "initialization" do
    it "defaults generation to 0" do
      ref = PDF::Objects::Reference.new(5)
      ref.generation.should eq(0)
    end

    it "raises for zero object number" do
      expect_raises(ArgumentError, "Object number must be positive") do
        PDF::Objects::Reference.new(0, 0)
      end
    end

    it "raises for negative object number" do
      expect_raises(ArgumentError, "Object number must be positive") do
        PDF::Objects::Reference.new(-1, 0)
      end
    end

    it "raises for negative generation" do
      expect_raises(ArgumentError, "Generation must be non-negative") do
        PDF::Objects::Reference.new(1, -1)
      end
    end
  end

  describe "#object_number" do
    it "returns the object number" do
      PDF::Objects::Reference.new(5, 0).object_number.should eq(5)
    end
  end

  describe "#generation" do
    it "returns the generation number" do
      PDF::Objects::Reference.new(5, 2).generation.should eq(2)
    end
  end

  describe "equality" do
    it "compares by object number and generation" do
      a = PDF::Objects::Reference.new(5, 0)
      b = PDF::Objects::Reference.new(5, 0)
      c = PDF::Objects::Reference.new(5, 1)
      d = PDF::Objects::Reference.new(6, 0)

      a.should eq(b)
      a.should_not eq(c)
      a.should_not eq(d)
    end

    it "has consistent hash" do
      a = PDF::Objects::Reference.new(5, 0)
      b = PDF::Objects::Reference.new(5, 0)

      a.hash.should eq(b.hash)
    end
  end
end
