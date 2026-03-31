# frozen_string_literal: true

module Examples
  # Example Rails controller for managing user subscriptions via Mainlayer.
  #
  # Shows how to:
  # 1. Track subscription state
  # 2. Sync subscriptions from the API
  # 3. Check entitlements
  # 4. Handle subscription lifecycle events
  class SubscriptionController < ApplicationController
    before_action :authenticate_user!

    # GET /subscriptions
    # List all subscriptions for the current user.
    def index
      subscriptions = current_user.mainlayer_subscriptions

      render json: {
        user_id: current_user.id,
        subscriptions: subscriptions.map { |sub| subscription_json(sub) }
      }
    end

    # GET /subscriptions/:id
    # Show details of a specific subscription.
    def show
      subscription = current_user.mainlayer_subscriptions.find(params[:id])
      render json: subscription_json(subscription)
    end

    # POST /subscriptions/sync
    # Sync the user's subscription state from Mainlayer.
    #
    # Body: { "wallet": "0x...", "resource_id": "res_api_v1" (optional) }
    def sync
      wallet = subscription_params[:wallet]
      resource_id = subscription_params[:resource_id]

      subscription = current_user.sync_mainlayer_subscription!(
        wallet: wallet,
        resource_id: resource_id
      )

      render json: {
        synced: true,
        subscription: subscription ? subscription_json(subscription) : nil,
        message: subscription ? 'Subscription is active.' : 'Subscription is inactive.'
      }
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # GET /subscriptions/check/:resource_id
    # Check if user is entitled to a specific resource.
    #
    # Params: resource_id (required)
    def check
      resource_id = params[:resource_id]
      is_entitled = current_user.entitled_to?(resource_id)

      render json: {
        user_id: current_user.id,
        resource_id: resource_id,
        is_entitled: is_entitled,
        message: is_entitled ? "User has access to #{resource_id}." : "User does not have access to #{resource_id}."
      }
    end

    # GET /subscriptions/entitlements
    # List all resources the user is entitled to.
    def entitlements
      render json: {
        user_id: current_user.id,
        entitlements: current_user.mainlayer_entitlements,
        count: current_user.mainlayer_entitlements.count
      }
    end

    # GET /subscriptions/expiring?days=7
    # List subscriptions expiring within N days.
    def expiring
      days = params[:days].to_i.clamp(1, 365) || 7

      subscriptions = current_user.mainlayer_subscriptions
        .where('expires_at IS NOT NULL')
        .where('expires_at >= ?', Time.current)
        .where('expires_at <= ?', Time.current + days.days)
        .order(:expires_at)

      render json: {
        user_id: current_user.id,
        days: days,
        subscriptions: subscriptions.map { |sub| subscription_json(sub) }
      }
    end

    # POST /subscriptions/renew/:id
    # Initiate renewal of a subscription.
    def renew
      subscription = current_user.mainlayer_subscriptions.find(params[:id])

      # In a real app, this would create a payment session
      # and return a payment URL to the client.
      session = Mainlayer.create_payment_session(
        resource: subscription.resource_id,
        amount: 10000,  # $100 in cents
        currency: 'USD',
        metadata: {
          user_id: current_user.id,
          subscription_id: subscription.id,
          action: 'renew'
        }
      )

      render json: {
        session_id: session['session_id'],
        payment_url: session['payment_url'],
        expires_at: session['expires_at']
      }
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def subscription_params
      params.require(:subscription).permit(:wallet, :resource_id)
    end

    def subscription_json(subscription)
      {
        id: subscription.id,
        wallet: subscription.wallet,
        resource_id: subscription.resource_id,
        status: subscription.status,
        is_active: subscription.status == 'active',
        entitlement_id: subscription.entitlement_id,
        expires_at: subscription.expires_at,
        synced_at: subscription.synced_at,
        created_at: subscription.created_at,
        updated_at: subscription.updated_at
      }
    end
  end
end
