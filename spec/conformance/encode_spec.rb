# frozen_string_literal: true

require "json"

RSpec.describe "TOON spec encode fixtures" do
  fixtures = File.expand_path("../toon-spec/tests/fixtures/encode", __dir__)

  Dir[File.join(fixtures, "*.json")].sort.each do |path|
    describe File.basename(path) do
      JSON.parse(File.read(path)).fetch("tests").each_with_index do |fixture, index|
        it "matches test ##{index}" do
          input = fixture.fetch("input")
          pending "objects and arrays are not encoded yet" if input.is_a?(Hash) || input.is_a?(Array)

          options = fixture.fetch("options", {})
          encoder = ToonFu::Encoder.new(delimiter: options.fetch("delimiter", ","), indent: options.fetch("indentSize", 2))

          if fixture["shouldError"]
            expect { encoder.encode(input) }.to raise_error(ToonFu::Error)
          else
            expect(encoder.encode(input)).to eq(fixture.fetch("expected"))
          end
        end
      end
    end
  end
end
