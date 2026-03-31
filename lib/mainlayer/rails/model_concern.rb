# frozen_string_literal: true

module Mainlayer
  module Rails
    # ActiveRecord concern that adds subscription-tracking capabilities to any
    # model.
    #
    # Usage:
    #
    #   class User < ApplicationRecord
    #     has_mainlayer_subscription
    #   end
    #
    # This macro:
    #   - Declares a has_many :mainlayer_subscriptions association pointing at
    #     the mainlayer_subscriptions table created by the gem migration.
    #   - Adds instance helpers: #active_subscription?, #active_subscription,
    #     #mainlayer_entitlements, #sync_mainlayer_subscription!
    #   - Adds class helpers: .with_active_subscription
    module ModelConcern
      extend ActiveSupport::Concern

      # Class-level macro DSL injected when the concern is included.
      module ClassMethods
        # Call this macro inside a model class to opt in to subscription tracking.
        #
        # @param resource_id [String, nil] optional default resource ID to use
        #   when checking entitlements without an explicit argument.
        # @return [void]
        def has_mainlayer_subscription(resource_id: nil) # rubocop:disable Naming/PredicateName
          # Store the default resource ID as a class-level attribute.
          class_attribute :mainlayer_default_resource_id, instance_accessor: false
          self.mainlayer_default_resource_id = resource_id

          has_many :mainlayer_subscriptions,
                   class_name:  "Mainlayer::Subscription",
                   foreign_key: :subscriber_id,
                   dependent:   :destroy

          include InstanceMethods
          extend  ScopeMethods
        end
      end

      # Instance helpers added after has_mainlayer_subscription is called.
      module InstanceMethods
        # Returns the most recently created active subscription record, or nil.
        #
        # @return [Mainlayer::Subscription, nil]
        def active_subscription
          mainlayer_subscriptions.active.order(created_at: :desc).first
        end

        # Returns true when at least one active subscription exists.
        #
        # @return [Boolean]
        def active_subscription?
          mainlayer_subscriptions.active.exists?
        end

        # Returns all resource IDs covered by active subscriptions.
        #
        # @return [Array<String>]
        def mainlayer_entitlements
          mainlayer_subscriptions.active.pluck(:resource_id).uniq
        end

        # Returns true when the subscriber holds an active entitlement for the
        # given resource_id.  Falls back to the class-level default when no
        # resource_id is provided.
        #
        # @param resource_id [String, nil]
        # @return [Boolean]
        def entitled_to?(resource_id = nil)
          rid = resource_id || self.class.mainlayer_default_resource_id
          raise ArgumentError, "resource_id is required" if rid.nil?

          mainlayer_entitlements.include?(rid)
        end

        # Fetches the latest subscription state from the Mainlayer API and
        # upserts the local mainlayer_subscriptions records accordingly.
        #
        # Returns the refreshed active subscription or nil.
        #
        # @param wallet [String] the payer wallet identifier
        # @param resource_id [String, nil] narrow the sync to one resource
        # @return [Mainlayer::Subscription, nil]
        def sync_mainlayer_subscription!(wallet:, resource_id: nil)
          rid = resource_id || self.class.mainlayer_default_resource_id

          entitlement_active = Mainlayer.check_entitlement(rid, wallet)

          sub = mainlayer_subscriptions.find_or_initialize_by(
            resource_id: rid,
            wallet:      wallet
          )

          sub.assign_attributes(
            status:      entitlement_active ? "active" : "inactive",
            synced_at:   Time.current,
            expires_at:  nil # populated by webhook when known
          )
          sub.save!

          entitlement_active ? sub : nil
        end
      end

      # Class-level scope helpers added after has_mainlayer_subscription is called.
      module ScopeMethods
        # Returns all records that have at least one active subscription.
        def with_active_subscription
          joins(:mainlayer_subscriptions)
            .merge(Mainlayer::Subscription.active)
            .distinct
        end
      end
    end
  end
end
