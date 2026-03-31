# frozen_string_literal: true

require "simplecov"
SimpleCov.start "rails" do
  add_filter "/spec/"
  minimum_coverage 80
end

require "webmock/rspec"
require "mainlayer/rails"

# Disallow all real HTTP in tests by default.
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  config.before(:suite) do
    # Ensure the Mainlayer base gem has a no-op check_entitlement during tests
    # unless explicitly stubbed.
    Mainlayer.configure do |c|
      c.api_key = "test_key_mainlayer_rails_spec"
    end
  end
end
