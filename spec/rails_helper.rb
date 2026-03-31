# frozen_string_literal: true

require "spec_helper"

# Minimal Rails app used only for specs — avoids needing a host application.
require "action_controller/railtie"
require "action_dispatch/routing"

module MainlayerSpecApp
  class Application < ::Rails::Application
    config.eager_load = false
    config.secret_key_base = "mainlayer_test_secret_key_base_for_specs_only"
    config.logger = Logger.new(nil)
    config.log_level = :fatal
  end
end

MainlayerSpecApp::Application.initialize!

Rails.application.routes.draw do
  mount Mainlayer::Engine, at: "/mainlayer"

  # Minimal test routes for controller specs.
  namespace :test_harness do
    get  "gated",   to: "resources#gated"
    post "create",  to: "resources#create_resource"
  end
end

RSpec.configure do |config|
  config.include Rails.application.routes.url_helpers

  config.before(:each, type: :controller) do
    @routes = Rails.application.routes
  end
end
