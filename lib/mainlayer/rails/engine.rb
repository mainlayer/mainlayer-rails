# frozen_string_literal: true

module Mainlayer
  module Rails
    # The Rails Engine mounts the Mainlayer payment endpoints under the
    # /mainlayer namespace and makes the gem's migrations and assets
    # available to the host application automatically.
    class Engine < ::Rails::Engine
      isolate_namespace Mainlayer

      # Ensure the gem's migrations can be copied to the host app with
      # `rails mainlayer:install:migrations`.
      initializer "mainlayer.migrations" do |app|
        unless app.root.to_s == root.to_s
          config.paths["db/migrate"].expanded.each do |expanded_path|
            app.config.paths["db/migrate"] << expanded_path
          end
        end
      end

      # Auto-include controller helpers in ActionController::Base so that
      # `require_mainlayer_payment` is available in every controller without
      # an explicit `include`.
      initializer "mainlayer.controller_helpers" do
        ActiveSupport.on_load(:action_controller_base) do
          include Mainlayer::Rails::ControllerHelpers
        end
      end

      # Auto-include the model concern into ActiveRecord::Base so that any
      # model can call `has_mainlayer_subscription` without a manual include.
      initializer "mainlayer.model_concern" do
        ActiveSupport.on_load(:active_record) do
          include Mainlayer::Rails::ModelConcern
        end
      end

      config.generators do |g|
        g.test_framework :rspec
        g.fixture_replacement :factory_bot
      end
    end
  end
end
