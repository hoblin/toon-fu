# frozen_string_literal: true

require "open3"

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

  it "loads through the gem name, as Bundler.require does" do
    lib = File.expand_path("../lib", __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, "-I", lib, "-e", 'require "toon-fu"; require "toon_fu"; print ToonFu.encode({a: 1})')
    expect([output, status.success?]).to eq(["a: 1", true])
  end

  it "loads without warnings" do
    lib = File.expand_path("../lib", __dir__)
    output, _status = Open3.capture2e(RbConfig.ruby, "-w", "-I", lib, "-e", 'require "toon_fu"')
    expect(output).to be_empty
  end
end
