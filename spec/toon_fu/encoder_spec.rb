# frozen_string_literal: true

RSpec.describe ToonFu::Encoder do
  subject(:encoder) { described_class.new }

  describe "numbers" do
    it "drops a zero fraction" do
      expect(encoder.encode(1.0)).to eq("1")
    end

    it "normalizes negative zero" do
      expect(encoder.encode(-0.0)).to eq("0")
    end

    it "writes integral floats up to 1e21 without an exponent" do
      expect(encoder.encode(1e20)).to eq("100000000000000000000")
    end

    it "writes small fractions down to 1e-6 without an exponent" do
      expect(encoder.encode(-1.5e-5)).to eq("-0.000015")
      expect(encoder.encode(1e-6)).to eq("0.000001")
    end

    it "keeps every digit of a long fraction" do
      expect(encoder.encode(123.456789012345)).to eq("123.456789012345")
    end

    it "uses a lowercase exponent with an explicit sign from 1e21 up" do
      expect(encoder.encode(1e21)).to eq("1e+21")
      expect(encoder.encode(-2.5e30)).to eq("-2.5e+30")
    end

    it "uses a lowercase exponent with an explicit sign below 1e-6" do
      expect(encoder.encode(1e-7)).to eq("1e-7")
      expect(encoder.encode(1.25e-10)).to eq("1.25e-10")
    end

    it "writes integers of any size as digits" do
      expect(encoder.encode(10**25)).to eq("10000000000000000000000000")
    end
  end

  describe "strings" do
    it "escapes control characters as lowercase \\uXXXX" do
      expect(encoder.encode("a\x1fb")).to eq('"a\\u001fb"')
    end

    it "quotes on leading or trailing whitespace" do
      expect(encoder.encode(" padded")).to eq('" padded"')
      expect(encoder.encode("padded\t")).to eq('"padded\\t"')
    end

    it "keeps inner spaces unquoted" do
      expect(encoder.encode("hello world")).to eq("hello world")
    end

    it "quotes an uppercase exponent that reads as a number" do
      expect(encoder.encode("1E5")).to eq('"1E5"')
    end

    it "leaves case variants of literals unquoted" do
      expect(encoder.encode("True")).to eq("True")
    end
  end

  describe "delimiter" do
    it "quotes a root string containing the chosen delimiter" do
      expect(described_class.new(delimiter: "|").encode("a|b")).to eq('"a|b"')
      expect(described_class.new(delimiter: "\t").encode("a\tb")).to eq('"a\\tb"')
    end

    it "leaves other delimiters unquoted" do
      expect(described_class.new(delimiter: "|").encode("a,b")).to eq("a,b")
    end

    it "rejects a delimiter the spec does not define" do
      expect { described_class.new(delimiter: ";") }.to raise_error(ArgumentError, /delimiter/)
    end
  end

  it "refuses values it cannot encode" do
    expect { encoder.encode(Object.new) }.to raise_error(ToonFu::Error, /Object/)
  end

  it "is what ToonFu.encode delegates to" do
    expect(ToonFu.encode("a|b", delimiter: "|")).to eq('"a|b"')
  end
end
