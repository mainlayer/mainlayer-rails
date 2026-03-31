# frozen_string_literal: true

require_relative "lib/mainlayer/rails/version"

Gem::Specification.new do |spec|
  spec.name        = "mainlayer-rails"
  spec.version     = Mainlayer::Rails::VERSION
  spec.authors     = ["Mainlayer"]
  spec.email       = ["support@mainlayer.xyz"]
  spec.homepage    = "https://mainlayer.xyz"
  spec.summary     = "Rails integration for Mainlayer payments"
  spec.description = "Mainlayer payments for Rails applications. " \
                     "Drop-in controller helpers, ActiveRecord concerns, " \
                     "and engine routes for monetising APIs served to AI agents."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mainlayer/mainlayer-rails"
  spec.metadata["changelog_uri"]   = "https://github.com/mainlayer/mainlayer-rails/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir[
    "lib/**/*",
    "app/**/*",
    "config/**/*",
    "db/**/*",
    "LICENSE",
    "README.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "mainlayer", ">= 0.1.0"
  spec.add_dependency "rails",     ">= 7.0"

  spec.add_development_dependency "rspec-rails",       ">= 6.0"
  spec.add_development_dependency "webmock",           ">= 3.23"
  spec.add_development_dependency "factory_bot_rails", ">= 6.0"
  spec.add_development_dependency "sqlite3",           ">= 1.4"
  spec.add_development_dependency "simplecov",         ">= 0.22"
  spec.add_development_dependency "rubocop",           ">= 1.60"
  spec.add_development_dependency "rubocop-rails",     ">= 2.23"
  spec.add_development_dependency "rubocop-rspec",     ">= 2.27"
end
