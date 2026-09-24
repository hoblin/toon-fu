# frozen_string_literal: true

RSpec.describe ToonFu::Encoder do
  subject(:encoder) { described_class.new }

  describe ".new" do
    it "rejects a delimiter the spec does not define" do
      expect { described_class.new(delimiter: ";") }.to raise_error(ArgumentError, /delimiter/)
    end

    it "rejects an indent_size that is not a positive Integer" do
      expect { described_class.new(indent_size: 0) }.to raise_error(ArgumentError, /indent_size/)
      expect { described_class.new(indent_size: "2") }.to raise_error(ArgumentError, /indent_size/)
    end
  end

  describe "#encode" do
    context "with floats" do
      it "drops a zero fraction" do
        expect(encoder.encode(1.0)).to eq("1")
      end

      it "normalizes negative zero" do
        expect(encoder.encode(-0.0)).to eq("0")
      end

      it "writes large integral floats with their shortest digits" do
        expect(encoder.encode(1e20)).to eq("100000000000000000000")
        expect(encoder.encode(1.2345678901234568e20)).to eq("123456789012345680000")
      end

      it "writes small fractions down to 1e-6 without an exponent" do
        expect(encoder.encode(-1.5e-5)).to eq("-0.000015")
        expect(encoder.encode(1e-6)).to eq("0.000001")
      end

      it "uses a lowercase exponent with an explicit sign from 1e21 up" do
        expect(encoder.encode(1e21)).to eq("1e+21")
        expect(encoder.encode(-2.5e30)).to eq("-2.5e+30")
      end

      it "uses a lowercase exponent with an explicit sign below 1e-6" do
        expect(encoder.encode(1e-7)).to eq("1e-7")
        expect(encoder.encode(1.25e-10)).to eq("1.25e-10")
      end

      it "writes NaN and infinities as null" do
        expect([Float::NAN, Float::INFINITY, -Float::INFINITY].map { |value| encoder.encode(value) }).to all(eq("null"))
      end
    end

    context "with strings" do
      it "escapes double quotes" do
        expect(encoder.encode('say "hi"')).to eq('"say \\"hi\\""')
      end

      it "escapes other control characters as lowercase \\uXXXX" do
        expect(encoder.encode("a\x1fb")).to eq('"a\\u001fb"')
      end

      it "quotes on leading or trailing whitespace" do
        expect(encoder.encode(" padded")).to eq('" padded"')
        expect(encoder.encode("\tpadded")).to eq('"\\tpadded"')
        expect(encoder.encode("padded ")).to eq('"padded "')
      end

      it "quotes an uppercase exponent that reads as a number" do
        expect(encoder.encode("1E5")).to eq('"1E5"')
      end

      it "leaves case variants of literals unquoted" do
        expect(encoder.encode("True")).to eq("True")
      end

      it "leaves a hyphen or number sign past the first character unquoted" do
        expect(encoder.encode("a-b")).to eq("a-b")
        expect(encoder.encode("a#b")).to eq("a#b")
      end
    end

    context "with a delimiter" do
      it "quotes a root string containing it" do
        expect(described_class.new(delimiter: "|").encode("a|b")).to eq('"a|b"')
      end

      it "leaves the other delimiters unquoted" do
        expect(described_class.new(delimiter: "|").encode("a,b")).to eq("a,b")
        expect(described_class.new(delimiter: "\t").encode("a,b")).to eq("a,b")
      end
    end

    context "with hashes" do
      it "encodes symbol and integer keys by their string form" do
        expect(encoder.encode({id: 1})).to eq("id: 1")
        expect(encoder.encode({2 => "x"})).to eq('"2": x')
      end

      it "leaves dotted keys unquoted" do
        expect(encoder.encode({"a.b" => 1})).to eq("a.b: 1")
      end

      it "refuses a value it cannot encode inside a hash" do
        expect { encoder.encode({at: Object.new}) }.to raise_error(ToonFu::Error, /Object/)
      end

      it "refuses a value it cannot encode inside an array" do
        expect { encoder.encode({tags: [Object.new]}) }.to raise_error(ToonFu::Error, /Object/)
      end
    end

    it "refuses values it cannot encode" do
      expect { encoder.encode(Object.new) }.to raise_error(ToonFu::Error, /Object/)
    end
  end
end
