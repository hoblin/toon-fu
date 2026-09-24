# frozen_string_literal: true

RSpec.describe ToonFu do
  it "has a version" do
    expect(ToonFu::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe ".encode" do
    it "passes options through to the encoder" do
      expect(ToonFu.encode("a|b", delimiter: "|")).to eq('"a|b"')
    end

    it "tells to wrap a Hash in braces when the value is missing" do
      expect { ToonFu.encode(users: [1]) }.to raise_error(ArgumentError, /wrap a Hash in braces/)
    end
  end
end
