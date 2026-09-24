# frozen_string_literal: true

require "bigdecimal"
require "date"

RSpec.describe ToonFu, ".encode with Ruby host types" do
  def encode(value) = described_class.encode(value)

  context "with mapped types" do
    it "writes symbols as their names" do
      expect(encode({status: :active})).to eq("status: active")
    end

    it "writes a set as an array" do
      expect(encode({ids: Set[1, 2]})).to eq("ids[2]: 1,2")
    end

    it "writes a date as its ISO 8601 date, whatever the time zone" do
      expect(encode({on: Date.new(2026, 5, 31)})).to eq("on: 2026-05-31")
    end

    it "writes a time as ISO 8601 with its offset and only non-zero fraction digits" do
      expect(encode({at: Time.utc(2026, 5, 31, 10)})).to eq('at: "2026-05-31T10:00:00Z"')
      expect(encode({at: Time.new(2026, 5, 31, 10, 0, 5.12r, "+03:00")})).to eq('at: "2026-05-31T10:00:05.12+03:00"')
    end

    it "writes a datetime like a time" do
      expect(encode({at: DateTime.new(2026, 5, 31, 10, 0, 0, "+03:00")})).to eq('at: "2026-05-31T10:00:00+03:00"')
    end

    it "writes a BigDecimal as its exact digits" do
      expect(encode({amount: BigDecimal("12345678901234567890.123")})).to eq("amount: 12345678901234567890.123")
      expect(encode({amount: BigDecimal("-0")})).to eq("amount: 0")
      expect(encode({amount: BigDecimal("NaN")})).to eq("amount: null")
    end

    it "unifies symbol and string keys before choosing a form" do
      expect(encode([{id: 1}, {"id" => 2}])).to eq("[2]{id}:\n  1\n  2")
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

    it "refuses an object whose implicit conversion leads back to itself" do
      loop = Object.new
      def loop.to_hash = {self: self}
      expect { encode(loop) }.to raise_error(ToonFu::Error, /circular/)
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

    it "refuses a hook that returns its own object" do
      echo = Object.new
      def echo.as_toon = self
      expect { encode(echo) }.to raise_error(ToonFu::Error, /as_toon returned the object itself/)
    end
  end

  context "with values the spec does not model" do
    it "refuses unknown objects and points to as_toon" do
      expect { encode({at: Object.new}) }.to raise_error(ToonFu::Error, /Object.*as_toon/)
    end

    it "refuses structs and data objects" do
      expect { encode(Struct.new(:a).new(1)) }.to raise_error(ToonFu::Error)
      expect { encode(Data.define(:a).new(a: 1)) }.to raise_error(ToonFu::Error)
    end

    it "refuses keys that collide once converted to strings" do
      expect { encode({:a => 1, "a" => 2}) }.to raise_error(ToonFu::Error, /duplicate key "a"/)
    end

    it "refuses keys other than strings, symbols and integers" do
      expect { encode({1.5 => "x"}) }.to raise_error(ToonFu::Error, /Float key/)
    end

    it "refuses circular references" do
      list = []
      list << list
      hash = {}
      hash[:self] = hash
      expect { encode(list) }.to raise_error(ToonFu::Error, /circular/)
      expect { encode(hash) }.to raise_error(ToonFu::Error, /circular/)
    end

    it "accepts the same object twice when it is not circular" do
      shared = {x: 1}
      expect(encode({a: shared, b: shared})).to eq("[2:]{x}:\n  a: 1\n  b: 1")
    end
  end

  context "with string encodings" do
    it "transcodes other encodings to UTF-8" do
      output = encode({name: "café".encode("ISO-8859-1")})
      expect(output).to eq("name: café")
      expect(output.encoding).to eq(Encoding::UTF_8)
    end

    it "reads binary strings holding valid UTF-8 as UTF-8" do
      expect(encode({name: "café".b})).to eq("name: café")
    end

    it "refuses bytes that are not valid UTF-8" do
      expect { encode({name: "\xFF".b}) }.to raise_error(ToonFu::Error, /UTF-8/)
      expect { encode({name: (+"\xC3(").force_encoding(Encoding::UTF_8)}) }.to raise_error(ToonFu::Error, /UTF-8/)
    end

    it "refuses an unpaired surrogate" do
      expect { encode({name: (+"\xED\xA0\x80").force_encoding(Encoding::UTF_8)}) }.to raise_error(ToonFu::Error, /UTF-8/)
    end
  end
end
