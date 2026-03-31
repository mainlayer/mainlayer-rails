# frozen_string_literal: true

require "spec_helper"
require "action_controller"
require "action_dispatch"
require "webmock/rspec"

RSpec.describe Mainlayer::Rails::ControllerHelpers do
  # ---------------------------------------------------------------------------
  # Test double controller
  # ---------------------------------------------------------------------------

  # A minimal ActionController::Metal subclass that includes the concern so we
  # can unit-test the helpers in isolation without a full Rails app.
  let(:controller_class) do
    Class.new(ActionController::Metal) do
      include ActionController::Rendering
      include ActionController::MimeResponds
      include ActionController::ImplicitRender
      include AbstractController::Callbacks
      include Mainlayer::Rails::ControllerHelpers

      def self.name = "TestResourcesController"

      def index
        require_mainlayer_payment(resource_id: "res_test_001")
        render plain: "ok"
      end

      def show
        require_mainlayer_payment(resource_id: "res_test_002", wallet: "wallet_override")
        render plain: "authorized"
      end
    end
  end

  let(:controller) { controller_class.new }

  # Builds a minimal Rack env so request helpers work.
  def build_request(headers: {})
    env = Rack::MockRequest.env_for("/", headers)
    ActionDispatch::Request.new(env)
  end

  before do
    Mainlayer.configure do |c|
      c.api_key = "test_api_key_for_specs"
    end
  end

  # ---------------------------------------------------------------------------
  # #mainlayer_payer_wallet
  # ---------------------------------------------------------------------------

  describe "#mainlayer_payer_wallet" do
    it "returns the value of the X-Payer-Wallet header" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "wallet_abc123" })
      controller.set_request!(req)
      expect(controller.mainlayer_payer_wallet).to eq("wallet_abc123")
    end

    it "returns nil when the header is absent" do
      req = build_request
      controller.set_request!(req)
      expect(controller.mainlayer_payer_wallet).to be_nil
    end

    it "returns nil when the header is an empty string" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "" })
      controller.set_request!(req)
      expect(controller.mainlayer_payer_wallet).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # #require_mainlayer_payment — entitled path
  # ---------------------------------------------------------------------------

  describe "#require_mainlayer_payment when entitled" do
    before do
      allow(Mainlayer).to receive(:check_entitlement).and_return(true)
    end

    it "does not render a 402 response" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "wallet_ok" })
      controller.set_request!(req)

      expect(controller).not_to receive(:render)
      controller.require_mainlayer_payment(resource_id: "res_premium")
    end

    it "passes the resource_id to check_entitlement" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "wallet_ok" })
      controller.set_request!(req)

      expect(Mainlayer).to receive(:check_entitlement).with("res_exact_id", "wallet_ok")
      controller.require_mainlayer_payment(resource_id: "res_exact_id")
    end

    it "passes the wallet header to check_entitlement" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "wallet_from_header" })
      controller.set_request!(req)

      expect(Mainlayer).to receive(:check_entitlement).with("res_x", "wallet_from_header")
      controller.require_mainlayer_payment(resource_id: "res_x")
    end

    it "uses an explicit wallet override when provided" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "header_wallet" })
      controller.set_request!(req)

      expect(Mainlayer).to receive(:check_entitlement).with("res_x", "explicit_wallet")
      controller.require_mainlayer_payment(resource_id: "res_x", wallet: "explicit_wallet")
    end
  end

  # ---------------------------------------------------------------------------
  # #require_mainlayer_payment — not entitled path
  # ---------------------------------------------------------------------------

  describe "#require_mainlayer_payment when not entitled" do
    before do
      allow(Mainlayer).to receive(:check_entitlement).and_return(false)
    end

    it "renders a JSON response" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "unpaid_wallet" })
      controller.set_request!(req)

      expect(controller).to receive(:render).with(
        hash_including(status: :payment_required),
        any_args
      )
      controller.require_mainlayer_payment(resource_id: "res_premium")
    end

    it "includes error key payment_required in the response body" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "unpaid_wallet" })
      controller.set_request!(req)

      captured_args = nil
      allow(controller).to receive(:render) { |args, *| captured_args = args }
      controller.require_mainlayer_payment(resource_id: "res_premium")

      body = captured_args[:json]
      expect(body[:error]).to eq("payment_required")
    end

    it "includes the resource_id in the response body" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "unpaid_wallet" })
      controller.set_request!(req)

      captured_args = nil
      allow(controller).to receive(:render) { |args, *| captured_args = args }
      controller.require_mainlayer_payment(resource_id: "res_abc")

      expect(captured_args[:json][:resource_id]).to eq("res_abc")
    end

    it "includes the pay_endpoint in the response body" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "unpaid_wallet" })
      controller.set_request!(req)

      captured_args = nil
      allow(controller).to receive(:render) { |args, *| captured_args = args }
      controller.require_mainlayer_payment(resource_id: "res_abc")

      expect(captured_args[:json][:pay_endpoint]).to eq("https://api.mainlayer.fr/pay")
    end

    it "returns HTTP 402 status" do
      req = build_request(headers: { "HTTP_X_PAYER_WALLET" => "unpaid_wallet" })
      controller.set_request!(req)

      captured_args = nil
      allow(controller).to receive(:render) { |args, *| captured_args = args }
      controller.require_mainlayer_payment(resource_id: "res_abc")

      expect(captured_args[:status]).to eq(:payment_required)
    end
  end

  # ---------------------------------------------------------------------------
  # Mainlayer API stub via WebMock
  # ---------------------------------------------------------------------------

  describe "entitlement check against Mainlayer API (WebMock)" do
    let(:base_url)   { "https://api.mainlayer.fr" }
    let(:wallet)     { "wlt_webmock_001" }
    let(:resource)   { "res_inference" }

    it "grants access when the API returns entitled: true" do
      stub_request(:get, "#{base_url}/entitlements")
        .with(
          query:   { resource_id: resource, wallet: wallet },
          headers: { "Authorization" => "Bearer test_api_key_for_specs" }
        )
        .to_return(
          status: 200,
          body:   { entitled: true }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Real call — WebMock intercepts it.
      result = Mainlayer.check_entitlement(resource, wallet)
      expect(result).to be(true)
    end

    it "denies access when the API returns entitled: false" do
      stub_request(:get, "#{base_url}/entitlements")
        .with(query: { resource_id: resource, wallet: wallet })
        .to_return(
          status: 200,
          body:   { entitled: false }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = Mainlayer.check_entitlement(resource, wallet)
      expect(result).to be(false)
    end

    it "treats a 401 Unauthorized from the API as not entitled" do
      stub_request(:get, "#{base_url}/entitlements")
        .with(query: { resource_id: resource, wallet: wallet })
        .to_return(status: 401, body: { error: "unauthorized" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      # Depending on the base gem implementation this may raise or return false.
      # We verify the outcome is falsy either way.
      result = begin
        Mainlayer.check_entitlement(resource, wallet)
      rescue StandardError
        false
      end
      expect(result).to be_falsy
    end

    it "treats a 404 from the API as not entitled" do
      stub_request(:get, "#{base_url}/entitlements")
        .with(query: { resource_id: resource, wallet: wallet })
        .to_return(status: 404, body: { error: "not_found" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = begin
        Mainlayer.check_entitlement(resource, wallet)
      rescue StandardError
        false
      end
      expect(result).to be_falsy
    end
  end

  # ---------------------------------------------------------------------------
  # PAY_ENDPOINT constant
  # ---------------------------------------------------------------------------

  describe "PAY_ENDPOINT constant" do
    it "is not publicly accessible (private_constant)" do
      expect { Mainlayer::Rails::ControllerHelpers::PAY_ENDPOINT }
        .to raise_error(NameError)
    end
  end
end
