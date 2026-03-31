# frozen_string_literal: true

# Creates the mainlayer_subscriptions table used by Mainlayer::Subscription
# (the ActiveRecord model backed by the ModelConcern).
#
# Run via:
#   rails mainlayer:install:migrations
#   rails db:migrate
class CreateMainlayerSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :mainlayer_subscriptions do |t|
      # Polymorphic owner — usually a User or Organisation record.
      t.references :subscriber,
                   null:       false,
                   polymorphic: true,
                   index:      true

      # The Mainlayer resource / API product identifier.
      t.string :resource_id, null: false

      # Wallet identifier supplied by the paying agent or end-user.
      t.string :wallet, null: false

      # Lifecycle state: active | inactive | cancelled | past_due
      t.string :status, null: false, default: "inactive"

      # Mainlayer subscription ID returned by the API (may be nil until the
      # first webhook is received).
      t.string :mainlayer_subscription_id

      # UTC timestamp of the last successful sync with the Mainlayer API.
      t.datetime :synced_at

      # UTC timestamp after which the subscription should be considered lapsed
      # (populated from webhook data).
      t.datetime :expires_at

      # Freeform metadata column for storing arbitrary API response fields.
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    # Enforce one subscription record per subscriber + resource + wallet combo.
    add_index :mainlayer_subscriptions,
              %i[subscriber_type subscriber_id resource_id wallet],
              unique: true,
              name:   "index_mainlayer_subscriptions_uniqueness"

    add_index :mainlayer_subscriptions, :status
    add_index :mainlayer_subscriptions, :mainlayer_subscription_id, unique: true,
              where: "mainlayer_subscription_id IS NOT NULL"
  end
end
