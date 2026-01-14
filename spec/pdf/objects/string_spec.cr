require "../../spec_helper"

describe PDF::Objects::Str do
  describe "#to_pdf" do
    context "with literal strings" do
      it "serializes simple strings" do
        PDF::Objects::Str.new("Hello").to_pdf.should eq("(Hello)")
      end

      it "serializes empty strings" do
        PDF::Objects::Str.new("").to_pdf.should eq("()")
      end

      it "escapes parentheses" do
        PDF::Objects::Str.new("Hello (World)").to_pdf.should eq("(Hello \\(World\\))")
      end

      it "escapes backslashes" do
        PDF::Objects::Str.new("C:\\path").to_pdf.should eq("(C:\\\\path)")
      end

      it "escapes newlines" do
        PDF::Objects::Str.new("Line1\nLine2").to_pdf.should eq("(Line1\\nLine2)")
      end

      it "escapes carriage returns" do
        PDF::Objects::Str.new("Line1\rLine2").to_pdf.should eq("(Line1\\rLine2)")
      end

      it "escapes tabs" do
        PDF::Objects::Str.new("Col1\tCol2").to_pdf.should eq("(Col1\\tCol2)")
      end

      it "escapes backspace" do
        PDF::Objects::Str.new("Back\bspace").to_pdf.should eq("(Back\\bspace)")
      end

      it "escapes form feed" do
        PDF::Objects::Str.new("Form\ffeed").to_pdf.should eq("(Form\\ffeed)")
      end

      it "escapes non-printable characters as octal" do
        # ASCII 1 (SOH)
        PDF::Objects::Str.new("\u0001").to_pdf.should eq("(\\001)")
      end
    end

    context "with hexadecimal strings" do
      it "serializes as hex" do
        PDF::Objects::Str.new("Hello", hex: true).to_pdf.should eq("<48656C6C6F>")
      end

      it "serializes empty hex strings" do
        PDF::Objects::Str.new("", hex: true).to_pdf.should eq("<>")
      end

      it "handles binary data" do
        # Bytes 0x00, 0xFF
        data = String.new(Bytes[0x00, 0xFF])
        PDF::Objects::Str.new(data, hex: true).to_pdf.should eq("<00FF>")
      end
    end
  end

  describe ".unicode" do
    it "uses literal for ASCII-only text" do
      str = PDF::Objects::Str.unicode("Hello")
      str.hex?.should be_false
      str.to_pdf.should eq("(Hello)")
    end

    it "uses hex with BOM for Unicode text" do
      str = PDF::Objects::Str.unicode("Helló")
      str.hex?.should be_true

      pdf = str.to_pdf
      # Should start with BOM (FEFF)
      pdf.should start_with("<FEFF")
      pdf.should end_with(">")
    end

    it "encodes emoji correctly" do
      # Emoji requires surrogate pairs
      str = PDF::Objects::Str.unicode("Hi 😀")
      str.hex?.should be_true
    end
  end

  describe "#hex?" do
    it "returns true for hex strings" do
      PDF::Objects::Str.new("test", hex: true).hex?.should be_true
    end

    it "returns false for literal strings" do
      PDF::Objects::Str.new("test", hex: false).hex?.should be_false
    end
  end

  describe "equality" do
    it "compares by value and type" do
      a = PDF::Objects::Str.new("Hello")
      b = PDF::Objects::Str.new("Hello")
      c = PDF::Objects::Str.new("Hello", hex: true)

      a.should eq(b)
      a.should_not eq(c) # Different serialization mode
    end
  end
end
