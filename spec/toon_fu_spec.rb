# frozen_string_literal: true

RSpec.describe ToonFu do
  it "has a version" do
    expect(ToonFu::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
