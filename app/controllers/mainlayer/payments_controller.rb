# frozen_string_literal: true

module Mainlayer
  # Handles payment initiation and entitlement status queries.
  #
  # Mounted at /mainlayer by the Engine. All routes are defined in
  # config/routes.rb relative to the engine root.
  class PaymentsController < ActionController::Base # rubocop:disable Rails/ApplicationController
    include Mainlayer::Rails::ControllerHelpers

    before_action :validate_api_key!

    # POST /mainlayer/pay
    #
    # Initiates a payment request for the given resource + wallet pair.
    # Returns a pay URL that the caller (agent or end-user) should visit to
    # complete the transaction.
    #
    # Required body params:
    #   resource_id [String] the Mainlayer resource ID
    #   wallet      [String] the payer's wallet identifier
    #
    # Responses:
    #   201 Created  — payment session opened, returns { pay_url:, session_id: }
    #   422 Unprocessable Entity — missing/invalid params
    #   502 Bad Gateway — upstream Mainlayer API error
    def create
      resource_id = payment_params[:resource_id]
      wallet      = payment_params[:wallet] || mainlayer_payer_wallet

      if resource_id.blank? || wallet.blank?
        return render json: {
          error:   "missing_params",
          message: "resource_id and wallet are required"
        }, status: :unprocessable_entity
      end

      result = initiate_payment(resource_id: resource_id, wallet: wallet)

      render json: result, status: :created
    rescue Mainlayer::ApiError => e
      render json: { error: "upstream_error", message: e.message }, status: :bad_gateway
    end

    # GET /mainlayer/status
    #
    # Queries the Mainlayer API for the current entitlement status of a
    # resource + wallet pair.
    #
    # Required query params:
    #   resource_id [String]
    #   wallet      [String]
    #
    # Responses:
    #   200 OK — { entitled: Boolean, resource_id:, wallet: }
    #   422 Unprocessable Entity — missing params
    #   502 Bad Gateway — upstream error
    def status
      resource_id = params[:resource_id]
      wallet      = params[:wallet] || mainlayer_payer_wallet

      if resource_id.blank? || wallet.blank?
        return render json: {
          error:   "missing_params",
          message: "resource_id and wallet are required"
        }, status: :unprocessable_entity
      end

      entitled = Mainlayer.check_entitlement(resource_id, wallet)

      render json: {
        entitled:    entitled,
        resource_id: resource_id,
        wallet:      wallet,
        checked_at:  Time.current.iso8601
      }
    rescue Mainlayer::ApiError => e
      render json: { error: "upstream_error", message: e.message }, status: :bad_gateway
    end

    private

    def payment_params
      params.permit(:resource_id, :wallet)
    end

    # Ensures an API key is configured before handling any request.
    def validate_api_key!
      return if Mainlayer.api_key.present?

      render json: {
        error:   "configuration_error",
        message: "Mainlayer API key is not configured"
      }, status: :internal_server_error
    end

    # Calls the Mainlayer pay endpoint and returns a normalised response hash.
    #
    # @param resource_id [String]
    # @param wallet      [String]
    # @return [Hash] containing at least :pay_url and :session_id
    def initiate_payment(resource_id:, wallet:)
      response = Mainlayer::Client.new.post(
        "/pay",
        body: { resource_id: resource_id, wallet: wallet }
      )

      {
        pay_url:     response.fetch("pay_url"),
        session_id:  response.fetch("session_id"),
        resource_id: resource_id,
        wallet:      wallet,
        created_at:  Time.current.iso8601
      }
    end
  end
end
