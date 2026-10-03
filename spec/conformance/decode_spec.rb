# frozen_string_literal: true

require "json"

RSpec.describe "TOON spec decode fixtures" do
  paths = Dir[File.expand_path("../toon-spec/tests/fixtures/decode/*.json", __dir__)].sort
  option_names = {"strict" => :strict, "indentSize" => :indent_size}
  deferred = JSON.parse(File.read(File.expand_path("decode_pending.json", __dir__)))

  it "finds the fixtures (run `git submodule update --init` if this fails)" do
    expect(paths).not_to be_empty
  end

  paths.each do |path|
    file = File.basename(path)
    waiting = deferred.fetch(file, [])

    describe file do
      JSON.parse(File.read(path)).fetch("tests").each_with_index do |fixture, index|
        name = fixture.fetch("name")

        it "matches test ##{index}: #{name}" do
          pending "a form a later decoder slice reads" if waiting.include?(name)

          decoder = ToonFu::Decoder.new(**fixture.fetch("options", {}).transform_keys(option_names))
          input = fixture.fetch("input")

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
