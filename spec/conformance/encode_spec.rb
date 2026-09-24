# frozen_string_literal: true

require "json"

RSpec.describe "TOON spec encode fixtures" do
  paths = Dir[File.expand_path("../toon-spec/tests/fixtures/encode/*.json", __dir__)].sort
  option_names = {"delimiter" => :delimiter, "indentSize" => :indent_size}
  contains_array = ->(value) { value.is_a?(Array) || (value.is_a?(Hash) && value.each_value.any?(&contains_array)) }

  it "finds the fixtures (run `git submodule update --init` if this fails)" do
    expect(paths).not_to be_empty
  end

  paths.each do |path|
    describe File.basename(path) do
      JSON.parse(File.read(path)).fetch("tests").each_with_index do |fixture, index|
        it "matches test ##{index}" do
          input = fixture.fetch("input")
          pending "arrays are not encoded yet" if contains_array.call(input)
          pending "keyed tabular form is not encoded yet" if fixture["expected"].to_s.match?(/\[\d+:/)

          encoder = ToonFu::Encoder.new(**fixture.fetch("options", {}).transform_keys(option_names))

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
