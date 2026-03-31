# frozen_string_literal: true

module Mainlayer
  module Rails
    # Railtie performs auto-configuration when the gem is loaded inside a
    # Rails application without going through the full Engine path (e.g. when
    # Rails API mode skips engine initializers).
    #
    # Responsibilities:
    #  - Read MAINLAYER_API_KEY from ENV and configure the base gem.
    #  - Emit a warning when the key is missing in non-test environments.
    #  - Expose a rake task namespace for maintenance operations.
    class Railtie < ::Rails::Railtie
      railtie_name :mainlayer

      # Configure the Mainlayer API key from the environment before the
      # application boots. This runs before config/initializers so that a
      # custom initializer can still override the value.
      config.before_initialize do
        api_key = ENV.fetch("MAINLAYER_API_KEY", nil)

        if api_key.present?
          ::Mainlayer.configure do |c|
            c.api_key = api_key
          end
        elsif !::Rails.env.test?
          ::Rails.logger&.warn(
            "[Mainlayer] MAINLAYER_API_KEY is not set. " \
            "Payment checks will fail. Set the environment variable or " \
            "call Mainlayer.configure { |c| c.api_key = '...' } in an initializer."
          )
        end
      end

      # Expose a generator for the install task.
      generators do
        require_relative "../generators/mainlayer/install_generator"
      end

      rake_tasks do
        namespace :mainlayer do
          desc "Print the current Mainlayer configuration (redacts the API key)"
          task config: :environment do
            key   = ::Mainlayer.api_key.to_s
            shown = key.empty? ? "(not set)" : "#{key[0, 8]}…"
            puts "[Mainlayer] api_key=#{shown}"
            puts "[Mainlayer] base_url=#{::Mainlayer.configuration.base_url}"
          end
        end
      end
    end
  end
end
