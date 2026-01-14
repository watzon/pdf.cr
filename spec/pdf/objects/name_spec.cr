require "../../spec_helper"

describe PDF::Objects::Name do
  describe "#to_pdf" do
    it "serializes simple names" do
      PDF::Objects::Name.new("Type").to_pdf.should eq("/Type")
    end

    it "serializes names with numbers" do
      PDF::Objects::Name.new("Font1").to_pdf.should eq("/Font1")
    end

    it "serializes single character names" do
      PDF::Objects::Name.new("A").to_pdf.should eq("/A")
    end

    it "escapes spaces" do
      PDF::Objects::Name.new("Name With Spaces").to_pdf.should eq("/Name#20With#20Spaces")
    end

    it "escapes parentheses" do
      PDF::Objects::Name.new("Name(With)Parens").to_pdf.should eq("/Name#28With#29Parens")
    end

    it "escapes angle brackets" do
      PDF::Objects::Name.new("Name<With>Angles").to_pdf.should eq("/Name#3CWith#3EAngles")
    end

    it "escapes square brackets" do
      PDF::Objects::Name.new("Name[With]Brackets").to_pdf.should eq("/Name#5BWith#5DBrackets")
    end

    it "escapes curly braces" do
      PDF::Objects::Name.new("Name{With}Braces").to_pdf.should eq("/Name#7BWith#7DBraces")
    end

    it "escapes forward slash" do
      PDF::Objects::Name.new("Name/With/Slashes").to_pdf.should eq("/Name#2FWith#2FSlashes")
    end

    it "escapes percent sign" do
      PDF::Objects::Name.new("Name%With%Percent").to_pdf.should eq("/Name#25With#25Percent")
    end

    it "escapes number sign" do
      PDF::Objects::Name.new("Name#With#Hash").to_pdf.should eq("/Name#23With#23Hash")
    end

    it "escapes control characters" do
      PDF::Objects::Name.new("Name\tWith\nControl").to_pdf.should eq("/Name#09With#0AControl")
    end

    it "escapes null character" do
      PDF::Objects::Name.new("Name\u0000Null").to_pdf.should eq("/Name#00Null")
    end
  end

  describe "#value" do
    it "returns the unescaped name" do
      PDF::Objects::Name.new("Type").value.should eq("Type")
    end
  end

  describe "#to_s" do
    it "returns the name as a string" do
      PDF::Objects::Name.new("Type").to_s.should eq("Type")
    end
  end

  describe "predefined names" do
    it "has TYPE" do
      PDF::Objects::Name::TYPE.to_pdf.should eq("/Type")
    end

    it "has PAGE" do
      PDF::Objects::Name::PAGE.to_pdf.should eq("/Page")
    end

    it "has CATALOG" do
      PDF::Objects::Name::CATALOG.to_pdf.should eq("/Catalog")
    end

    it "has FLATEDECODE" do
      PDF::Objects::Name::FLATEDECODE.to_pdf.should eq("/FlateDecode")
    end
  end

  describe "equality" do
    it "compares by value" do
      a = PDF::Objects::Name.new("Type")
      b = PDF::Objects::Name.new("Type")
      c = PDF::Objects::Name.new("Page")

      a.should eq(b)
      a.should_not eq(c)
    end

    it "has consistent hash" do
      a = PDF::Objects::Name.new("Type")
      b = PDF::Objects::Name.new("Type")

      a.hash.should eq(b.hash)
    end
  end
end
