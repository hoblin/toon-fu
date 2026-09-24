# frozen_string_literal: true

require "toon_fu"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :random
  config.pending_failure_output = :skip
  Kernel.srand config.seed
end
