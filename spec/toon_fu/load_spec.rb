# frozen_string_literal: true

require "open3"

RSpec.describe "require \"toon_fu\"" do
  it "loads and encodes in a plain Ruby process without gems or bundler" do
    lib = File.expand_path("../../lib", __dir__)
    script = 'require "toon_fu"; print ToonFu.encode({ids: Set[1, 2]}), " ", Date.new(2026, 5, 31).to_toon'
    output, status = Open3.capture2e({"RUBYOPT" => nil}, RbConfig.ruby, "--disable-gems", "-I", lib, "-e", script)
    expect(output).to eq("ids[2]: 1,2 2026-05-31")
    expect(status).to be_success
  end
end
