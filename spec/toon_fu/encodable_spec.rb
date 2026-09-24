# frozen_string_literal: true

RSpec.describe ToonFu::Encodable do
  {
    Hash => {users: [{id: 1, name: "Ada"}]},
    Array => [1, "a,b", nil],
    Set => Set[1, 2],
    String => "a|b",
    Symbol => :active,
    Integer => 42,
    Float => 1.5e-7,
    TrueClass => true,
    FalseClass => false,
    NilClass => nil,
    Time => Time.utc(2026, 5, 31, 10)
  }.each do |klass, value|
    it "gives #{klass} a to_toon equal to ToonFu.encode" do
      expect(value.to_toon(delimiter: "|")).to eq(ToonFu.encode(value, delimiter: "|"))
    end
  end

  it "raises what ToonFu.encode raises", :aggregate_failures do
    expect { {at: Object.new}.to_toon }.to raise_error(ToonFu::Error)
    expect { [1].to_toon(delimiter: ";") }.to raise_error(ArgumentError, /delimiter/)
  end

  it "gives to_toon to a class that includes it and defines as_toon" do
    money = Class.new do
      include ToonFu::Encodable

      def as_toon = {cents: 150}
    end
    expect(money.new.to_toon).to eq("cents: 150")
  end

  it "leaves a to_toon a class defines itself in place" do
    custom = Class.new(Hash) { def to_toon(**) = "custom" }
    expect(custom.new.to_toon).to eq("custom")
  end
end
