# frozen_string_literal: true

module Mainlayer
  # ActiveRecord model backed by the mainlayer_subscriptions table.
  #
  # Instances are created and kept in sync either by:
  #  - ModelConcern#sync_mainlayer_subscription! (polling path)
  #  - WebhooksController#receive (push path, preferred)
  class Subscription < ActiveRecord::Base
    self.table_name = "mainlayer_subscriptions"

    # The Rails model that owns this subscription (e.g. User, Organisation).
    belongs_to :subscriber, polymorphic: true

    # ---------------------------------------------------------------------------
    # Validations
    # ---------------------------------------------------------------------------

    validates :resource_id, presence: true
    validates :wallet,      presence: true
    validates :status,      inclusion: { in: %w[active inactive cancelled past_due] }

    # ---------------------------------------------------------------------------
    # Scopes
    # ---------------------------------------------------------------------------

    scope :active,      -> { where(status: "active") }
    scope :inactive,    -> { where(status: "inactive") }
    scope :cancelled,   -> { where(status: "cancelled") }
    scope :past_due,    -> { where(status: "past_due") }
    scope :not_expired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

    # Active *and* not yet past the expiry timestamp.
    scope :current, -> { active.not_expired }

    # ---------------------------------------------------------------------------
    # Instance helpers
    # ---------------------------------------------------------------------------

    # Returns true when the subscription is active and has not expired.
    #
    # @return [Boolean]
    def current?
      active? && (expires_at.nil? || expires_at > Time.current)
    end

    # Returns true when the subscription status field equals "active".
    #
    # @return [Boolean]
    def active?
      status == "active"
    end

    # Returns true when the subscription has an expiry date in the past.
    #
    # @return [Boolean]
    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    # Convenience method to transition the status to cancelled and persist.
    #
    # @return [Boolean]
    def cancel!
      update!(status: "cancelled")
    end

    # Convenience method to mark the subscription as active and persist.
    #
    # @return [Boolean]
    def activate!
      update!(status: "active", synced_at: Time.current)
    end
  end
end
