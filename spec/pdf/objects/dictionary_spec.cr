require "../../spec_helper"

describe PDF::Objects::Dictionary do
  describe "#to_pdf" do
    it "serializes empty dictionaries" do
      PDF::Objects::Dictionary.new.to_pdf.should eq("<<>>")
    end

    it "serializes single entry" do
      dict = PDF::Objects::Dictionary.new
      dict["Type"] = PDF::Objects::Name.new("Page")
      dict.to_pdf.should eq("<</Type /Page>>")
    end

    it "serializes multiple entries" do
      dict = PDF::Objects::Dictionary.new
      dict["Type"] = PDF::Objects::Name.new("Page")
      dict["Count"] = PDF::Objects::Number.new(5)

      pdf = dict.to_pdf
      pdf.should start_with("<<")
      pdf.should end_with(">>")
      pdf.should contain("/Type /Page")
      pdf.should contain("/Count 5")
    end

    it "serializes nested dictionaries" do
      inner = PDF::Objects::Dictionary.new
      inner["Nested"] = PDF::Objects::Boolean.new(true)

      outer = PDF::Objects::Dictionary.new
      outer["Inner"] = inner

      pdf = outer.to_pdf
      pdf.should contain("/Inner <</Nested true>>")
    end

    it "serializes with array values" do
      dict = PDF::Objects::Dictionary.new
      arr = PDF::Objects::Array.new([0, 0, 612, 792])
      dict["MediaBox"] = arr

      dict.to_pdf.should contain("/MediaBox [0 0 612 792]")
    end
  end

  describe "access by Name" do
    it "sets and gets by Name object" do
      dict = PDF::Objects::Dictionary.new
      key = PDF::Objects::Name.new("Type")
      value = PDF::Objects::Name.new("Page")

      dict[key] = value
      dict[key].should eq(value)
    end

    it "returns nil for missing keys with []?" do
      dict = PDF::Objects::Dictionary.new
      dict[PDF::Objects::Name.new("Missing")]?.should be_nil
    end

    it "raises for missing keys with []" do
      dict = PDF::Objects::Dictionary.new
      expect_raises(KeyError) do
        dict[PDF::Objects::Name.new("Missing")]
      end
    end
  end

  describe "access by String" do
    it "sets and gets by String" do
      dict = PDF::Objects::Dictionary.new
      value = PDF::Objects::Name.new("Page")

      dict["Type"] = value
      dict["Type"].should eq(value)
    end

    it "returns nil for missing string keys with []?" do
      dict = PDF::Objects::Dictionary.new
      dict["Missing"]?.should be_nil
    end
  end

  describe "#has_key?" do
    it "returns true for existing Name key" do
      dict = PDF::Objects::Dictionary.new
      dict["Type"] = PDF::Objects::Name.new("Page")

      dict.has_key?(PDF::Objects::Name.new("Type")).should be_true
    end

    it "returns true for existing String key" do
      dict = PDF::Objects::Dictionary.new
      dict["Type"] = PDF::Objects::Name.new("Page")

      dict.has_key?("Type").should be_true
    end

    it "returns false for missing key" do
      dict = PDF::Objects::Dictionary.new
      dict.has_key?("Missing").should be_false
    end
  end

  describe "#delete" do
    it "deletes by Name" do
      dict = PDF::Objects::Dictionary.new
      dict["Type"] = PDF::Objects::Name.new("Page")

      dict.delete(PDF::Objects::Name.new("Type"))
      dict.has_key?("Type").should be_false
    end

    it "deletes by String" do
      dict = PDF::Objects::Dictionary.new
      dict["Type"] = PDF::Objects::Name.new("Page")

      dict.delete("Type")
      dict.has_key?("Type").should be_false
    end

    it "returns deleted value" do
      dict = PDF::Objects::Dictionary.new
      value = PDF::Objects::Name.new("Page")
      dict["Type"] = value

      dict.delete("Type").should eq(value)
    end

    it "returns nil for missing key" do
      dict = PDF::Objects::Dictionary.new
      dict.delete("Missing").should be_nil
    end
  end

  describe "#each" do
    it "iterates over entries" do
      dict = PDF::Objects::Dictionary.new
      dict["A"] = PDF::Objects::Number.new(1)
      dict["B"] = PDF::Objects::Number.new(2)

      keys = [] of String
      dict.each { |k, _| keys << k.value }

      keys.should contain("A")
      keys.should contain("B")
    end
  end

  describe "#keys" do
    it "returns all keys" do
      dict = PDF::Objects::Dictionary.new
      dict["A"] = PDF::Objects::Number.new(1)
      dict["B"] = PDF::Objects::Number.new(2)

      key_values = dict.keys.map(&.value)
      key_values.should contain("A")
      key_values.should contain("B")
    end
  end

  describe "#values" do
    it "returns all values" do
      dict = PDF::Objects::Dictionary.new
      dict["A"] = PDF::Objects::Number.new(1)
      dict["B"] = PDF::Objects::Number.new(2)

      dict.values.size.should eq(2)
    end
  end

  describe "#size" do
    it "returns entry count" do
      dict = PDF::Objects::Dictionary.new
      dict.size.should eq(0)

      dict["A"] = PDF::Objects::Number.new(1)
      dict.size.should eq(1)
    end
  end

  describe "#empty?" do
    it "returns true for empty dictionaries" do
      PDF::Objects::Dictionary.new.empty?.should be_true
    end

    it "returns false for non-empty dictionaries" do
      dict = PDF::Objects::Dictionary.new
      dict["A"] = PDF::Objects::Number.new(1)
      dict.empty?.should be_false
    end
  end

  describe "#merge!" do
    it "merges another dictionary" do
      dict1 = PDF::Objects::Dictionary.new
      dict1["A"] = PDF::Objects::Number.new(1)

      dict2 = PDF::Objects::Dictionary.new
      dict2["B"] = PDF::Objects::Number.new(2)

      dict1.merge!(dict2)

      dict1.has_key?("A").should be_true
      dict1.has_key?("B").should be_true
    end

    it "overwrites existing keys" do
      dict1 = PDF::Objects::Dictionary.new
      dict1["A"] = PDF::Objects::Number.new(1)

      dict2 = PDF::Objects::Dictionary.new
      dict2["A"] = PDF::Objects::Number.new(99)

      dict1.merge!(dict2)

      (dict1["A"].as(PDF::Objects::Number)).value.should eq(99)
    end
  end
end
