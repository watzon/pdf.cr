require "../../spec_helper"

describe PDF::Objects::Null do
  describe "#to_pdf" do
    it "serializes to null" do
      null = PDF::Objects::Null.new
      null.to_pdf.should eq("null")
    end
  end

  describe ".instance" do
    it "returns the singleton instance" do
      PDF::Objects::Null.instance.should be(PDF::Objects::Null::INSTANCE)
    end

    it "all instances are equal" do
      a = PDF::Objects::Null.new
      b = PDF::Objects::Null.new

      a.should eq(b)
      a.hash.should eq(b.hash)
    end
  end
end
