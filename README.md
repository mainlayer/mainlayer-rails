# Mainlayer Rails Gem

Official Rails integration for **Mainlayer** — payment infrastructure for AI agents and modern APIs.

Add payment gating, subscription tracking, and entitlement management to any Rails application with minimal setup.

## Features

- **Controller Helpers**: `require_mainlayer_payment` for payment-gating actions
- **View Helpers**: Render payment buttons and subscription status
- **ActiveRecord Concern**: `has_mainlayer_subscription` for User models
- **Engine with Routes**: Built-in webhook handling and payment endpoints
- **Configuration**: Sensible defaults via initializer
- **Rails 7.0+**: Full support for modern Rails versions
- **Comprehensive Logging**: Request tracking for debugging

## Installation

### 1. Bundler

Add to `Gemfile`:

```ruby
gem 'mainlayer-rails'
```

Then run:

```bash
bundle install
```

### 2. Environment

Add to `.env` or your environment:

```env
MAINLAYER_API_KEY=ml_live_your_api_key
MAINLAYER_BASE_URL=https://api.mainlayer.fr
```

### 3. Generate Config

```bash
rails generate mainlayer:install
```

This creates `config/initializers/mainlayer.rb` with all options.

### 4. Run Migrations

```bash
rails db:migrate
```

## Quick Start

### Protect Controller Actions

```ruby
class DataController < ApplicationController
  include Mainlayer::Rails::ControllerHelpers

  before_action -> { require_mainlayer_payment(resource_id: 'res_api_v1') }

  def index
    render json: { data: expensive_data }
  end
end
```

Or inline:

```ruby
def show
  require_mainlayer_payment(resource_id: 'res_api_v1')
  render json: { item: Item.find(params[:id]) }
end
```

### Track Subscriptions on Models

```ruby
class User < ApplicationRecord
  has_mainlayer_subscription
end

user = User.first

# Check subscription status
user.active_subscription?       # => true/false
user.active_subscription        # => MainlayerSubscription or nil

# Get entitlements
user.mainlayer_entitlements     # => ['res_api_v1', 'res_data_v2']
user.entitled_to?('res_api_v1') # => true/false

# Sync from API
user.sync_mainlayer_subscription!(wallet: user.wallet, resource_id: 'res_api_v1')

# Find users with active subscriptions
User.with_active_subscription.pluck(:email)
```

### Render Payment Buttons in Views

```erb
<h1>Premium Content</h1>

<% if current_user.entitled_to?('res_premium') %>
  <p>You have access!</p>
<% else %>
  <%= mainlayer_subscribe_button('res_premium', 'Get Access') %>
<% end %>
```

## Configuration

Create `config/initializers/mainlayer.rb`:

```ruby
Mainlayer::Rails.configure do |config|
  # Your API key (required)
  config.api_key = ENV['MAINLAYER_API_KEY']

  # API base URL (default: https://api.mainlayer.fr)
  config.base_url = ENV['MAINLAYER_BASE_URL']

  # HTTP timeout in seconds
  config.timeout = 30

  # Cache strategy: :memory, :redis, :none
  config.cache_driver = :memory
  config.cache_ttl = 60

  # Webhook secret for signature verification
  config.webhook_secret = ENV['MAINLAYER_WEBHOOK_SECRET']

  # Fail open on API outage?
  config.fail_open = true

  # Logging
  config.logging_enabled = true
  config.log_level = :debug
end
```

## Controller Helpers

The `Mainlayer::Rails::ControllerHelpers` concern adds:

### `require_mainlayer_payment(resource_id:, wallet: nil)`

Gate an action behind a Mainlayer entitlement check.

```ruby
before_action -> { require_mainlayer_payment(resource_id: 'res_api') }
```

If the payer doesn't have an active entitlement, responds with HTTP 402 Payment Required:

```json
{
  "error": "payment_required",
  "resource_id": "res_api",
  "pay_endpoint": "https://api.mainlayer.fr/pay",
  "message": "Payment required..."
}
```

### `mainlayer_payer_wallet`

Access the wallet from the `X-Payer-Wallet` header:

```ruby
def check_balance
  wallet = mainlayer_payer_wallet
  # Look up wallet balance...
end
```

## View Helpers

The gem automatically adds view helpers for rendering Mainlayer UI.

### `mainlayer_subscribe_button(resource_id, label = 'Subscribe')`

Render a button that initiates payment:

```erb
<%= mainlayer_subscribe_button('res_premium', 'Unlock Premium') %>
```

### `mainlayer_payment_status(resource_id, wallet)`

Check payment status in the view:

```erb
<% if mainlayer_payment_status('res_api', current_wallet) %>
  <p>Paid!</p>
<% else %>
  <p>Not paid yet.</p>
<% end %>
```

## ActiveRecord Concern

Add `has_mainlayer_subscription` to any model:

```ruby
class User < ApplicationRecord
  has_mainlayer_subscription
end
```

### Provided Methods

- `active_subscription` — Get the most recent active subscription
- `active_subscription?` — Check if any active subscription exists
- `mainlayer_entitlements` — Get all resource IDs with active subscriptions
- `entitled_to?(resource_id)` — Check entitlement to specific resource
- `sync_mainlayer_subscription!(wallet:, resource_id: nil)` — Sync from API

### Database Schema

The migration creates:

```ruby
create_table :mainlayer_subscriptions do |t|
  t.references :subscriber, polymorphic: true, null: false
  t.string :wallet, null: false
  t.string :resource_id, null: false
  t.string :status, default: 'inactive'
  t.uuid :entitlement_id
  t.timestamp :expires_at
  t.timestamp :synced_at
  t.timestamps

  t.index [:subscriber_type, :subscriber_id, :resource_id], unique: true
  t.index [:wallet, :status]
end
```

## Engine Routes

The gem includes a Rails Engine with webhook and payment endpoints.

### Mount the Engine

Add to `config/routes.rb`:

```ruby
mount Mainlayer::Engine => '/mainlayer'
```

### Available Routes

- `POST /mainlayer/webhooks` — Receive payment webhooks from Mainlayer
- `POST /mainlayer/pay` — Initiate a payment session
- `GET /mainlayer/status` — Check payment status

## Webhook Handling

The engine provides a webhook receiver at `POST /mainlayer/webhooks`.

Mainlayer sends webhook events for:

- `subscription.activated` — User purchased an entitlement
- `subscription.renewed` — Subscription was renewed
- `subscription.deactivated` — Subscription expired or was revoked

Verify webhooks using the `webhook_secret`:

```ruby
# In your webhook handler
if Mainlayer::Rails.verify_webhook(body, signature, secret)
  # Process webhook
else
  # Invalid signature
end
```

## Testing

The gem includes 15+ RSpec tests:

```bash
bundle exec rspec
```

### Mocking Mainlayer

```ruby
allow(Mainlayer).to receive(:check_entitlement)
  .with('res_api', wallet)
  .and_return(true)
```

## Examples

See the `examples/` directory for complete examples:

- `SubscriptionController.rb` — User subscription management
- `WebhookHandler.rb` — Processing Mainlayer webhooks

## Troubleshooting

### "Payment Required" on every request

Check that the client is sending the token in the correct header:

```bash
curl -H "X-Payer-Wallet: 0x..." https://api.example.com/protected
```

### Subscriptions not syncing

Enable logging to debug:

```ruby
Mainlayer::Rails.configure do |config|
  config.logging_enabled = true
  config.log_level = :debug
end
```

Check `log/mainlayer.log`.

## Security

- API keys are environment-based (never committed to version control)
- Wallet addresses are case-normalized
- Webhook signatures are verified
- All API calls use HTTPS
- Sensitive data is never logged

## License

MIT License. See LICENSE file for details.

## Support

- Documentation: https://docs.mainlayer.fr
- Issues: https://github.com/mainlayer/mainlayer-rails/issues
- Contact: support@mainlayer.xyz

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
