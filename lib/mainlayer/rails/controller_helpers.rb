# frozen_string_literal: true

module Mainlayer
  module Rails
    # Controller concern that adds payment-gating helpers.
    #
    # Included automatically in ActionController::Base by the Engine initializer.
    # Can also be included manually in API-only controllers:
    #
    #   class MyController < ActionController::API
    #     include Mainlayer::Rails::ControllerHelpers
    #   end
    module ControllerHelpers
      extend ActiveSupport::Concern

      PAY_ENDPOINT = "https://api.mainlayer.fr/pay"
      private_constant :PAY_ENDPOINT

      included do
        # Expose helper methods to views as well if Action View is present.
        helper_method :mainlayer_payer_wallet if respond_to?(:helper_method)
      end

      # Gates an action behind a Mainlayer entitlement check.
      #
      # If the payer does not hold an active entitlement for +resource_id+ the
      # response is halted with HTTP 402 Payment Required and a JSON body that
      # tells the caller where and how to pay.
      #
      # @param resource_id [String] the Mainlayer resource / API product ID
      # @param wallet [String, nil] override the wallet address; defaults to the
      #   X-Payer-Wallet request header
      # @return [void]
      #
      # @example In a before_action block
      #   before_action -> { require_mainlayer_payment(resource_id: "res_inference_v1") }
      #
      # @example Inline inside an action
      #   def show
      #     require_mainlayer_payment(resource_id: params[:resource_id])
      #     render json: expensive_result
      #   end
      def require_mainlayer_payment(resource_id:, wallet: nil)
        payer_wallet = wallet || mainlayer_payer_wallet

        unless Mainlayer.check_entitlement(resource_id, payer_wallet)
          render json: payment_required_body(resource_id), status: :payment_required
        end
      end

      # Returns the wallet address supplied by the caller via the
      # X-Payer-Wallet request header, or nil when absent.
      #
      # @return [String, nil]
      def mainlayer_payer_wallet
        request.headers["X-Payer-Wallet"].presence
      end

      private

      def payment_required_body(resource_id)
        {
          error:        "payment_required",
          resource_id:  resource_id,
          pay_endpoint: PAY_ENDPOINT,
          message:      "Payment is required to access this resource. " \
                        "Visit pay_endpoint to complete payment."
        }
      end
    end
  end
end
