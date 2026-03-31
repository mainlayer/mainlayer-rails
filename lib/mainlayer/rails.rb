# frozen_string_literal: true

require "mainlayer"
require "rails"

require_relative "rails/version"
require_relative "rails/engine"
require_relative "rails/railtie"
require_relative "rails/controller_helpers"
require_relative "rails/model_concern"

module Mainlayer
  module Rails
    class Error < StandardError; end

    # Raised when the Mainlayer API key has not been configured.
    class ConfigurationError < Error; end

    # Raised when an entitlement check returns an unexpected response shape.
    class EntitlementError < Error; end

    class << self
      # Convenience accessor so callers can write Mainlayer::Rails.api_key
      # without going through the base Mainlayer module each time.
      def api_key
        ::Mainlayer.api_key
      end

      def api_key=(key)
        ::Mainlayer.api_key = key
      end

      # Rails-level configuration block, merges with base gem config.
      #
      # @example
      #   Mainlayer::Rails.configure do |config|
      #     config.api_key = ENV["MAINLAYER_API_KEY"]
      #   end
      def configure
        yield ::Mainlayer.configuration if block_given?
      end
    end
  end
end
