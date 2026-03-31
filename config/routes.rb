# frozen_string_literal: true

Mainlayer::Engine.routes.draw do
  # POST /mainlayer/pay
  # Initiates or confirms a payment for a resource.
  # Body: { resource_id: String, wallet: String }
  post "pay",    to: "payments#create"

  # GET /mainlayer/status
  # Returns the entitlement status for a resource + wallet combination.
  # Params: resource_id, wallet
  get  "status", to: "payments#status"

  # POST /mainlayer/webhooks
  # Receives lifecycle events from the Mainlayer platform (subscription
  # activated, deactivated, renewed, etc.).
  post "webhooks", to: "webhooks#receive"
end
