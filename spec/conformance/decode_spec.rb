# frozen_string_literal: true

require "json"

RSpec.describe "TOON spec decode fixtures" do
  paths = Dir[File.expand_path("../toon-spec/tests/fixtures/decode/*.json", __dir__)].sort
  option_names = {"strict" => :strict, "indentSize" => :indent_size}

  it "finds the fixtures (run `git submodule update --init` if this fails)" do
    expect(paths).not_to be_empty
  end

  paths.each do |path|
    describe File.basename(path) do
      JSON.parse(File.read(path)).fetch("tests").each_with_index do |fixture, index|
        it "matches test ##{index}: #{fixture.fetch("name")}" do
          input = fixture.fetch("input")
          decoder = ToonFu::Decoder.new(**fixture.fetch("options", {}).transform_keys(option_names))

          if fixture["shouldError"]
            expect { decoder.decode(input) }.to raise_error(ToonFu::Error)
          else
            expect(decoder.decode(input)).to eq(fixture.fetch("expected"))
          end
        end
      end
    end
  end
end
