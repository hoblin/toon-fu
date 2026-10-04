# frozen_string_literal: true

require "open3"

RSpec.describe "exe/toon" do
  def pipe(input)
    root = File.expand_path("../..", __dir__)
    out, status = Open3.capture2(RbConfig.ruby, "-I#{root}/lib", "#{root}/exe/toon", stdin_data: input)
    expect(status).to be_success
    out
  end

  it "encodes JSON on stdin" do
    expect(pipe('{"users":[{"id":1,"name":"Ada"},{"id":2,"name":"Bob"}]}')).to eq("users[2]{id,name}:\n  1,Ada\n  2,Bob\n")
  end

  it "passes input through when it is not JSON", :aggregate_failures do
    expect(pipe("gh: Not Found (HTTP 404)")).to eq("gh: Not Found (HTTP 404)\n")
    expect(pipe("")).to eq("\n")
  end

  it "passes input through when the value has no TOON representation" do
    expect(pipe('{"a":"\ud800"}')).to eq('{"a":"\ud800"}' + "\n")
  end
end
