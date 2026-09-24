# frozen_string_literal: true

require "bigdecimal"

RSpec.describe ToonFu, ".encode with Ruby host types" do
  def encode(value) = described_class.encode(value)

  context "with mapped types" do
    it "writes symbols as their names" do
      expect(encode({status: :active})).to eq("status: active")
    end

    it "writes a set as an array" do
      expect(encode({ids: Set[1, 2]})).to eq("ids[2]: 1,2")
    end

    context "east of Greenwich" do
      around do |example|
        zone = ENV["TZ"]
        ENV["TZ"] = "Asia/Tokyo"
        example.run
      ensure
        ENV["TZ"] = zone
      end

      it "writes a date as its ISO 8601 date, not the previous day" do
        expect(encode({on: Date.new(2026, 5, 31)})).to eq("on: 2026-05-31")
      end
    end

    it "writes a time as ISO 8601 with its offset and fraction digits up to the last non-zero one", :aggregate_failures do
      expect(encode({at: Time.utc(2026, 5, 31, 10)})).to eq('at: "2026-05-31T10:00:00Z"')
      expect(encode({at: Time.new(2026, 5, 31, 10, 0, 5.12r, "+03:00")})).to eq('at: "2026-05-31T10:00:05.12+03:00"')
      expect(encode({at: Time.new(2026, 5, 31, 10, 0, 5.102r, "-05:00")})).to eq('at: "2026-05-31T10:00:05.102-05:00"')
    end

    it "writes a datetime like a time, keeping its calendar day", :aggregate_failures do
      expect(encode({at: DateTime.new(2026, 5, 31, 10, 0, 5.25r, "+03:00")})).to eq('at: "2026-05-31T10:00:05.25+03:00"')
      expect(encode({at: DateTime.new(1000, 1, 1)})).to eq('at: "1000-01-01T00:00:00+00:00"')
    end

    it "writes integers of any size as their exact digits" do
      expect(encode({n: 2**100})).to eq("n: 1267650600228229401496703205376")
    end

    it "writes a BigDecimal as its exact digits", :aggregate_failures do
      expect(encode({amount: BigDecimal("12345678901234567890.123")})).to eq("amount: 12345678901234567890.123")
      expect(encode({amount: BigDecimal(100)})).to eq("amount: 100")
      expect(encode({amount: BigDecimal("-0")})).to eq("amount: 0")
    end

    it "writes a BigDecimal outside the canonical decimal range in exponent form, like a Float", :aggregate_failures do
      expect(encode({amount: BigDecimal("1e30")})).to eq("amount: 1e+30")
      expect(encode({amount: BigDecimal("-1.25e-7")})).to eq("amount: -1.25e-7")
    end

    it "writes a non-finite BigDecimal as null", :aggregate_failures do
      expect(encode({amount: BigDecimal("NaN")})).to eq("amount: null")
      expect(encode({amount: BigDecimal("Infinity")})).to eq("amount: null")
    end

    it "unifies symbol and string keys before choosing a form", :aggregate_failures do
      expect(encode([{id: 1}, {"id" => 2}])).to eq("[2]{id}:\n  1\n  2")
      expect(encode({a: {x: 1}, b: {"x" => 2}})).to eq("[2:]{x}:\n  a: 1\n  b: 2")
    end

    it "accepts the same object twice when it is not circular" do
      shared = {x: 1}
      expect(encode({a: shared, b: shared})).to eq("[2:]{x}:\n  a: 1\n  b: 1")
    end

    it "always returns UTF-8", :aggregate_failures do
      expect(encode(42).encoding).to eq(Encoding::UTF_8)
      expect(encode({}).encoding).to eq(Encoding::UTF_8)
    end
  end

  context "with Ruby's implicit conversions" do
    it "encodes an object that declares itself a hash, array or string" do
      record = Object.new
      def record.to_hash = {id: 1}
      list = Object.new
      def list.to_ary = [1, 2]
      name = Object.new
      def name.to_str = "Ada"
      expect(encode({record:, list:, name:})).to eq("record:\n  id: 1\nlist[2]: 1,2\nname: Ada")
    end

    it "refuses an implicit conversion that leads back to its own object", :aggregate_failures do
      loop = Object.new
      def loop.to_hash = {self: self}
      echo = Object.new
      def echo.to_str = self
      expect { encode(loop) }.to raise_error(ToonFu::Error, /circular/)
      expect { encode(echo) }.to raise_error(ToonFu::Error, /circular/)
    end

    it "does not guess from explicit conversions like to_h" do
      pairs = Object.new
      def pairs.to_h = {a: 1}
      expect { encode(pairs) }.to raise_error(ToonFu::Error)
    end
  end

  context "with the as_toon hook" do
    it "encodes the hook's result, normalised in turn" do
      money = Struct.new(:cents) { def as_toon = {cents:, on: Date.new(2026, 1, 2)} }
      expect(encode({price: money.new(150)})).to eq("price:\n  cents: 150\n  on: 2026-01-02")
    end

    it "takes precedence over the built-in mappings" do
      date = Date.new(2026, 5, 31)
      def date.as_toon = "end of May"
      expect(encode({on: date})).to eq("on: end of May")
    end

    it "refuses hooks that lead back to their own object", :aggregate_failures do
      echo = Object.new
      def echo.as_toon = self
      ping = Object.new
      pong = Object.new
      ping.define_singleton_method(:as_toon) { pong }
      pong.define_singleton_method(:as_toon) { ping }
      expect { encode(echo) }.to raise_error(ToonFu::Error, /circular/)
      expect { encode(ping) }.to raise_error(ToonFu::Error, /circular/)
    end

    it "refuses a hook whose fresh result leads back to its own object" do
      node = Struct.new(:parent, :children) { def as_toon = {parent:, children: children.dup} }
      root = node.new(nil, [])
      root.children << node.new(root, [])
      expect { encode(root) }.to raise_error(ToonFu::Error, /circular/)
    end
  end

  context "with values the spec does not model" do
    it "refuses unknown objects and points to as_toon", :aggregate_failures do
      expect { encode({at: Object.new}) }.to raise_error(ToonFu::Error, /Object.*as_toon/)
      expect { encode({at: BasicObject.new}) }.to raise_error(ToonFu::Error, /BasicObject/)
    end

    it "refuses structs and data objects", :aggregate_failures do
      expect { encode(Struct.new(:a).new(1)) }.to raise_error(ToonFu::Error)
      expect { encode(Data.define(:a).new(a: 1)) }.to raise_error(ToonFu::Error)
    end

    it "refuses keys that collide once converted to strings", :aggregate_failures do
      expect { encode({:a => 1, "a" => 2}) }.to raise_error(ToonFu::Error, /duplicate key "a"/)
      expect { encode({1 => "a", "1" => "b"}) }.to raise_error(ToonFu::Error, /duplicate key "1"/)
      expect { encode({"é".b => 1, "é" => 2}) }.to raise_error(ToonFu::Error, /duplicate key "é"/)
      expect { encode({"é".encode("ISO-8859-1") => 1, "é" => 2}) }.to raise_error(ToonFu::Error, /duplicate key "é"/)
    end

    it "refuses equal string keys in a hash that compares keys by identity" do
      hash = {}.compare_by_identity
      hash["a".dup] = 1
      hash["a".dup] = 2
      expect { encode(hash) }.to raise_error(ToonFu::Error, /duplicate key "a"/)
    end

    it "refuses keys other than strings, symbols and integers" do
      expect { encode({1.5 => "x"}) }.to raise_error(ToonFu::Error, /Float key/)
    end

    it "refuses circular references", :aggregate_failures do
      list = []
      list << list
      hash = {}
      hash[:self] = hash
      named = {}
      named["self"] = named
      expect { encode(list) }.to raise_error(ToonFu::Error, /circular/)
      expect { encode(hash) }.to raise_error(ToonFu::Error, /circular/)
      expect { encode(named) }.to raise_error(ToonFu::Error, /circular/)
    end

    it "refuses nesting too deep for the stack" do
      deep = 1
      100_000.times { deep = [deep] }
      expect { encode(deep) }.to raise_error(ToonFu::Error, /nesting too deep/)
    end
  end

  context "with a value that needs converting after plain ones" do
    it "keeps every entry before and after it", :aggregate_failures do
      expect(encode({"a" => 1, "b" => :x, "c" => 3})).to eq("a: 1\nb: x\nc: 3")
      expect(encode(["a", :b, "c"])).to eq("[3]: a,b,c")
    end
  end

  context "with Hash and Array subclasses" do
    it "encodes their contents as a plain Hash or Array would", :aggregate_failures do
      lookup = Class.new(Hash) { def [](key) = "overridden" }
      list = Class.new(Array)
      expect(encode([lookup[{"id" => 1}], lookup[{"id" => 2}]])).to eq("[2]{id}:\n  1\n  2")
      expect(encode({"ids" => list[1, 2]})).to eq("ids[2]: 1,2")
    end
  end

  context "with string encodings" do
    it "transcodes other encodings to UTF-8", :aggregate_failures do
      output = encode({name: "café".encode("ISO-8859-1")})
      expect(output).to eq("name: café")
      expect(output.encoding).to eq(Encoding::UTF_8)
    end

    it "reads binary strings holding valid UTF-8 as UTF-8" do
      expect(encode({name: "café".b})).to eq("name: café")
    end

    it "applies the same rules to string keys", :aggregate_failures do
      expect(encode({"café".encode("ISO-8859-1") => 1})).to eq('"café": 1')
      expect(encode({"café".b => 1})).to eq('"café": 1')
      expect { encode({"\xFF".b => 1}) }.to raise_error(ToonFu::Error, /UTF-8/)
    end

    it "refuses bytes that are not valid UTF-8", :aggregate_failures do
      expect { encode({name: "\xFF".b}) }.to raise_error(ToonFu::Error, /UTF-8/)
      expect { encode({name: (+"\xC3(").force_encoding(Encoding::UTF_8)}) }.to raise_error(ToonFu::Error, /UTF-8/)
      expect { encode({name: (+"\x82").force_encoding(Encoding::Shift_JIS)}) }.to raise_error(ToonFu::Error, /UTF-8/)
    end

    it "refuses an unpaired surrogate in any encoding", :aggregate_failures do
      expect { encode({name: (+"\xED\xA0\x80").force_encoding(Encoding::UTF_8)}) }.to raise_error(ToonFu::Error, /UTF-8/)
      expect { encode({name: (+"\x00\xD8").force_encoding(Encoding::UTF_16LE)}) }.to raise_error(ToonFu::Error, /UTF-8/)
    end
  end
end
