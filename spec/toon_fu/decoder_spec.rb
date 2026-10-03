# frozen_string_literal: true

RSpec.describe ToonFu::Decoder do
  subject(:decoder) { described_class.new }

  describe ".new" do
    it "rejects a strict that is not a boolean" do
      expect { described_class.new(strict: nil) }.to raise_error(ArgumentError, /strict/)
      expect { described_class.new(strict: "yes") }.to raise_error(ArgumentError, /strict/)
    end

    it "rejects an indent_size that is not a positive Integer" do
      expect { described_class.new(indent_size: 0) }.to raise_error(ArgumentError, /indent_size/)
      expect { described_class.new(indent_size: "2") }.to raise_error(ArgumentError, /indent_size/)
    end
  end

  describe "#decode" do
    context "with numbers outside the Float range" do
      it "refuses a magnitude Float cannot hold" do
        expect { decoder.decode("1e400") }.to raise_error(ToonFu::Error, /magnitude/)
        expect { decoder.decode("-1e400") }.to raise_error(ToonFu::Error, /magnitude/)
      end

      it "refuses a magnitude that would underflow to zero" do
        expect { decoder.decode("1e-400") }.to raise_error(ToonFu::Error, /magnitude/)
      end

      it "decodes an integer of any size exactly" do
        expect(decoder.decode("a: #{10**40}")).to eq({"a" => 10**40})
      end

      it "keeps a zero written with an exponent" do
        expect(decoder.decode("0e1")).to eq(0)
      end
    end

    context "with text that is not UTF-8" do
      it "transcodes an encoding that converts cleanly" do
        expect(decoder.decode("café".encode(Encoding::ISO_8859_1))).to eq("café")
      end

      it "accepts binary bytes that are valid UTF-8" do
        expect(decoder.decode("café".dup.force_encoding(Encoding::BINARY))).to eq("café")
      end

      it "refuses bytes that are not valid UTF-8" do
        expect { decoder.decode("\xff\xfe".dup.force_encoding(Encoding::BINARY)) }.to raise_error(ToonFu::Error, /UTF-8/)
      end
    end

    context "with keys that look like other types" do
      it "keeps every key a String", :aggregate_failures do
        %w[true false null 42 1.5 -0 1e3].each do |key|
          expect(decoder.decode("#{key}: 1").keys).to eq([key])
        end
      end

      it "unescapes a quoted key" do
        expect(decoder.decode('"a:b": 1')).to eq({"a:b" => 1})
      end
    end

    context "with whitespace around a token" do
      it "trims spaces only, keeping other whitespace in the token", :aggregate_failures do
        expect(decoder.decode("a:  spaced  ")).to eq({"a" => "spaced"})
        expect(decoder.decode("a: \tx")).to eq({"a" => "\tx"})
        expect(decoder.decode("a: 1\t")).to eq({"a" => "1\t"})
        expect(decoder.decode("a\t: b")).to eq({"a\t" => "b"})
      end

      it "treats a line of any whitespace as blank", :aggregate_failures do
        ["   ", "\t", "\v"].each do |blank|
          expect(decoder.decode("a: 1\n#{blank}\nb: 2")).to eq({"a" => 1, "b" => 2})
        end
      end
    end

    context "with a root form carrying indentation" do
      it "classifies it by its content", :aggregate_failures do
        expect(decoder.decode("  []")).to eq([])
        expect(decoder.decode("  hello")).to eq("hello")
        expect(decoder.decode("  42")).to eq(42)
      end
    end

    context "with a colon before the first bracket" do
      it "reads the line as a key-value pair, not a header" do
        expect(decoder.decode("a:b[2]: x")).to eq({"a" => "b[2]: x"})
      end
    end

    context "with a key carrying no value" do
      it "reads a bare key as an empty object, not an empty string" do
        expect(decoder.decode("matches:")).to eq({"matches" => {}})
      end

      it "reads an explicit empty array" do
        expect(decoder.decode("matches: []")).to eq({"matches" => []})
      end
    end

    context "with a value that is not a String" do
      it "refuses it" do
        expect { decoder.decode(42) }.to raise_error(ToonFu::Error, /String/)
        expect { decoder.decode(nil) }.to raise_error(ToonFu::Error, /String/)
      end
    end

    context "with duplicate keys" do
      it "refuses them when strict" do
        expect { decoder.decode("a: 1\na: 2") }.to raise_error(ToonFu::Error, /duplicate key/)
      end

      it "keeps the last one written when not strict" do
        expect(described_class.new(strict: false).decode("a: 1\na: 2")).to eq({"a" => 2})
      end
    end

    context "with indentation" do
      it "refuses a tab when strict" do
        expect { decoder.decode("a: 1\n\tb: 2") }.to raise_error(ToonFu::Error, /tab/)
      end

      it "refuses leading spaces that are not a multiple of indent_size when strict" do
        expect { decoder.decode("a: 1\n   b: 2") }.to raise_error(ToonFu::Error, /multiple/)
      end
    end

    it "reads a document many times with one decoder" do
      expect(decoder.decode("a: 1")).to eq({"a" => 1})
      expect(decoder.decode("b: two")).to eq({"b" => "two"})
    end

    context "round-tripping the encoder's output" do
      hostile = [
        "Ada", "has, comma", "a|b", "tab\there", %(say "hi"), "back\\slash",
        "#x", "-dash", "", " padded ", "05", "+1", ".5", "1.", "1_000",
        "Infinity", "NaN", "true", "null", "[]", "a:b", "{brace}", " nbsp",
        "line\nbreak", "🚀", "café"
      ].freeze

      it "reads back every scalar as a value", :aggregate_failures do
        hostile.each do |scalar|
          expect(decoder.decode(ToonFu.encode({"k" => scalar}))).to eq({"k" => scalar})
        end
      end

      it "reads back every scalar as a key", :aggregate_failures do
        hostile.reject(&:empty?).each do |scalar|
          expect(decoder.decode(ToonFu.encode({scalar => 1}))).to eq({scalar => 1})
        end
      end

      it "reads back the other primitive types", :aggregate_failures do
        [36, -7, 0, 10**40, 3.14, -0.001, 1e-7, 1e21, true, false, nil].each do |value|
          expect(decoder.decode(ToonFu.encode({"k" => value}))).to eq({"k" => value})
        end
      end
    end
  end
end
