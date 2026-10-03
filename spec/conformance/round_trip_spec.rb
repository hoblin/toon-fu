# frozen_string_literal: true

require "json"

RSpec.describe "TOON round trip" do
  paths = Dir[File.expand_path("../toon-spec/tests/fixtures/encode/*.json", __dir__)].sort
  option_names = {"delimiter" => :delimiter, "indentSize" => :indent_size}

  paths.each do |path|
    describe File.basename(path) do
      JSON.parse(File.read(path)).fetch("tests").each_with_index do |fixture, index|
        next if fixture["shouldError"]

        it "reads back test ##{index}" do
          options = fixture.fetch("options", {}).transform_keys(option_names)
          toon = ToonFu::Encoder.new(**options).encode(fixture.fetch("input"))
          decoder = ToonFu::Decoder.new(indent_size: options.fetch(:indent_size, 2))

          expect(decoder.decode(toon)).to eq(fixture.fetch("input"))
        end
      end
    end
  end
end
