require "../../spec_helper"

describe PDF::Objects::Boolean do
  describe "#to_pdf" do
    it "serializes true" do
      bool = PDF::Objects::Boolean.new(true)
      bool.to_pdf.should eq("true")
    end

    it "serializes false" do
      bool = PDF::Objects::Boolean.new(false)
      bool.to_pdf.should eq("false")
    end
  end

  describe "#value" do
    it "returns the boolean value" do
      PDF::Objects::Boolean.new(true).value.should be_true
      PDF::Objects::Boolean.new(false).value.should be_false
    end
  end

  describe "#to_b" do
    it "allows boolean coercion" do
      PDF::Objects::Boolean.new(true).to_b.should be_true
      PDF::Objects::Boolean.new(false).to_b.should be_false
    end
  end

  describe "equality" do
    it "compares by value" do
      a = PDF::Objects::Boolean.new(true)
      b = PDF::Objects::Boolean.new(true)
      c = PDF::Objects::Boolean.new(false)

      a.should eq(b)
      a.should_not eq(c)
    end

    it "has consistent hash" do
      a = PDF::Objects::Boolean.new(true)
      b = PDF::Objects::Boolean.new(true)

      a.hash.should eq(b.hash)
    end
  end
end
