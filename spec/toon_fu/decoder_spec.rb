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

      it "takes the type from the token, not the value", :aggregate_failures do
        expect(decoder.decode("250")).to be_an(Integer)
        expect(decoder.decode("2.5e2")).to be_a(Float)
        expect(decoder.decode("-1E+03")).to be_a(Float)
        expect(decoder.decode("2.5e2")).to eq(250)
      end

      it "normalizes a negative zero", :aggregate_failures do
        expect(decoder.decode("-0")).to eql(0)
        expect(decoder.decode("-0.0").to_s).to eq("0.0")
        expect(decoder.decode("-0e1").to_s).to eq("0.0")
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

      it "checks a root form's own indentation when strict", :aggregate_failures do
        expect { decoder.decode("   hello") }.to raise_error(ToonFu::Error, /multiple/)
        expect { decoder.decode("   []") }.to raise_error(ToonFu::Error, /multiple/)
        expect { decoder.decode("\thello") }.to raise_error(ToonFu::Error, /tab/)
      end

      it "counts a leading tab as one level when not strict", :aggregate_failures do
        lenient = described_class.new(strict: false)
        expect(lenient.decode("a:\n\tb: 1")).to eq({"a" => {"b" => 1}})
        expect(lenient.decode("items[1]{id}:\n\t1")).to eq({"items" => [{"id" => 1}]})
      end
    end

    context "at a tabular row's depth" do
      it "ends the rows at a line whose colon precedes the delimiter" do
        expect { decoder.decode("a[2]{x,y}:\n  1,2\n  k: 3,4") }.to raise_error(ToonFu::Error, /1 row/)
      end

      it "keeps a row whose delimiter precedes its colon" do
        expect(decoder.decode("a[1]{x,y}:\n  1,b: 2")).to eq({"a" => [{"x" => 1, "y" => "b: 2"}]})
      end
    end

    context "with a keyed header carrying no field list" do
      it "refuses it when strict" do
        expect { decoder.decode("a[2:]: x,y") }.to raise_error(ToonFu::Error, /malformed/)
      end

      it "reads the line as a key-value pair when not strict" do
        expect(described_class.new(strict: false).decode("a[2:]: x,y")).to eq({"a[2" => "]: x,y"})
      end
    end

    context "with a fields-bearing header carrying inline content" do
      it "refuses it when strict" do
        expect { decoder.decode("a[2]{x,y}: 1,2") }.to raise_error(ToonFu::Error, /malformed/)
      end

      it "reads the line as a key-value pair when not strict" do
        expect(described_class.new(strict: false).decode("a[2]{x,y}: 1,2")).to eq({"a[2]{x,y}" => "1,2"})
      end
    end

    it "names the line a duplicate key repeats on", :aggregate_failures do
      expect { decoder.decode("a[4:]{x}:\n  k: 1\n  z: 9\n  k: 2\n  w: 7") }.to raise_error(ToonFu::Error, /line 4/)
      expect { decoder.decode("a[1]:\n  - x: 1\n    y: 2\n    z: 3\n    x: 9") }.to raise_error(ToonFu::Error, /line 5/)
    end

    it "refuses nesting past the documented limit", :aggregate_failures do
      nest = ->(levels) { (0...levels).map { |i| "  " * i + "k#{i}:" }.join("\n") + "\n#{"  " * levels}leaf: 1" }
      expect(decoder.decode(nest.call(100))).to be_a(Hash)
      expect { decoder.decode(nest.call(101)) }.to raise_error(ToonFu::Error, /deeper than 100/)
    end

    it "reads a document many times with one decoder" do
      expect(decoder.decode("a: 1")).to eq({"a" => 1})
      expect(decoder.decode("b: two")).to eq({"b" => "two"})
    end

    it "reads inside a Ractor" do
      decoded = begin
        verbose, $VERBOSE = $VERBOSE, nil
        ractor = Ractor.new { ToonFu.decode("x[2]: 1,2") }
        ractor.respond_to?(:value) ? ractor.value : ractor.take
      ensure
        $VERBOSE = verbose
      end

      expect(decoded).to eq({"x" => [1, 2]})
    end

    context "with a quoted token" do
      it "unescapes it and keeps it a string", :aggregate_failures do
        {
          '"has, comma"' => "has, comma",
          '"a|b"' => "a|b",
          '"tab\\there"' => "tab\there",
          '"say \\"hi\\""' => %(say "hi"),
          '"back\\\\slash"' => "back\\slash",
          '"#x"' => "#x",
          '"-dash"' => "-dash",
          '""' => "",
          '" padded "' => " padded ",
          '"a:b"' => "a:b",
          '"{brace}"' => "{brace}",
          '"line\\nbreak"' => "line\nbreak",
          '"\u00a0nbsp"' => "\u00a0nbsp",
          '"05"' => "05",
          '"true"' => "true"
        }.each do |token, value|
          expect(decoder.decode("k: #{token}")).to eq({"k" => value})
          expect(decoder.decode("#{token}: 1")).to eq({value => 1})
        end
      end
    end
  end
end
