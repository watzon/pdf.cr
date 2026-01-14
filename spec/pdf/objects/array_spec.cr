require "../../spec_helper"

describe PDF::Objects::Array do
  describe "#to_pdf" do
    it "serializes empty arrays" do
      PDF::Objects::Array.new.to_pdf.should eq("[]")
    end

    it "serializes single element arrays" do
      arr = PDF::Objects::Array.new
      arr << PDF::Objects::Number.new(42)
      arr.to_pdf.should eq("[42]")
    end

    it "serializes multiple elements with spaces" do
      arr = PDF::Objects::Array.new
      arr << PDF::Objects::Number.new(1)
      arr << PDF::Objects::Number.new(2)
      arr << PDF::Objects::Number.new(3)
      arr.to_pdf.should eq("[1 2 3]")
    end

    it "serializes mixed types" do
      arr = PDF::Objects::Array.new
      arr << PDF::Objects::Number.new(42)
      arr << PDF::Objects::Str.new("test")
      arr << PDF::Objects::Name.new("Name")
      arr << PDF::Objects::Boolean.new(true)
      arr.to_pdf.should eq("[42 (test) /Name true]")
    end

    it "serializes nested arrays" do
      inner = PDF::Objects::Array.new
      inner << PDF::Objects::Number.new(1)
      inner << PDF::Objects::Number.new(2)

      outer = PDF::Objects::Array.new
      outer << inner
      outer << PDF::Objects::Number.new(3)

      outer.to_pdf.should eq("[[1 2] 3]")
    end
  end

  describe "initialization" do
    it "creates from array of objects" do
      elements = [
        PDF::Objects::Number.new(1).as(PDF::Objects::Base),
        PDF::Objects::Number.new(2).as(PDF::Objects::Base),
      ]
      arr = PDF::Objects::Array.new(elements)
      arr.size.should eq(2)
    end

    it "creates from numeric array" do
      arr = PDF::Objects::Array.new([1, 2, 3])
      arr.to_pdf.should eq("[1 2 3]")
    end
  end

  describe "Indexable" do
    it "supports indexing" do
      arr = PDF::Objects::Array.new
      arr << PDF::Objects::Number.new(42)

      arr[0].should be_a(PDF::Objects::Number)
      (arr[0].as(PDF::Objects::Number)).value.should eq(42)
    end

    it "supports size" do
      arr = PDF::Objects::Array.new
      arr.size.should eq(0)

      arr << PDF::Objects::Number.new(1)
      arr.size.should eq(1)
    end

    it "supports iteration" do
      arr = PDF::Objects::Array.new
      arr << PDF::Objects::Number.new(1)
      arr << PDF::Objects::Number.new(2)

      values = arr.map { |el| el.as(PDF::Objects::Number).value }
      values.should eq([1_i64, 2_i64])
    end
  end

  describe "mutation" do
    it "supports << operator" do
      arr = PDF::Objects::Array.new
      result = arr << PDF::Objects::Number.new(1)

      result.should be(arr)
      arr.size.should eq(1)
    end

    it "supports push" do
      arr = PDF::Objects::Array.new
      arr.push(PDF::Objects::Number.new(1))
      arr.size.should eq(1)
    end

    it "supports []=" do
      arr = PDF::Objects::Array.new
      arr << PDF::Objects::Number.new(1)
      arr[0] = PDF::Objects::Number.new(99)

      (arr[0].as(PDF::Objects::Number)).value.should eq(99)
    end

    it "supports clear" do
      arr = PDF::Objects::Array.new
      arr << PDF::Objects::Number.new(1)
      arr.clear
      arr.empty?.should be_true
    end
  end

  describe "#empty?" do
    it "returns true for empty arrays" do
      PDF::Objects::Array.new.empty?.should be_true
    end

    it "returns false for non-empty arrays" do
      arr = PDF::Objects::Array.new
      arr << PDF::Objects::Number.new(1)
      arr.empty?.should be_false
    end
  end
end
