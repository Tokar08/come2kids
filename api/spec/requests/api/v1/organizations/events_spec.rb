# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Organizations::Events", type: :request do
  let(:organization) { create(:organization) }
  let(:category) { create(:category) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:path) { "/api/v1/organizations/#{organization.id}/events" }

  def post_event(event = {}, headers: auth_headers(owner))
    post path, params: { event: event }, headers: headers, as: :json
  end

  describe "POST /api/v1/organizations/:organization_id/events" do
    let(:valid_params) do
      {
        category_id: category.id,
        start_at: "2026-12-01T10:00:00Z",
        end_at: "2026-12-01T12:00:00Z",
        time_zone: "Europe/Kyiv",
        location_type: "offline",
        address: "вул. Хрещатик, 1",
        city: "Київ",
        status: "published",
        translations: [ { locale: "uk", title: "Майстерня", description: "Опис" } ],
        ticket_types: [ { name: "Дорослий", price: 0, total_quantity: 20, currency: "USD" } ]
      }
    end

    context "when the owner sends a complete draft" do
      before { post_event(valid_params) }

      it "returns created" do
        expect(response).to have_http_status(:created)
      end

      it "stores a draft authored by the caller" do
        body = response.parsed_body["data"]

        expect(body["status"]).to eq("draft")
        expect(body["event_translations"]).to contain_exactly(
          a_hash_including("locale" => "uk", "title" => "Майстерня")
        )
        expect(body["ticket_types"]).to contain_exactly(
          a_hash_including("name" => "Дорослий", "price" => 0, "currency" => "UAH", "sold_quantity" => 0, "total_quantity" => 20)
        )
        expect(Event.last.created_by).to eq(owner)
      end
    end

    context "when the manager sends only the event shell" do
      before do
        manager = create(:company_member, :manager, organization: organization).user
        post_event({}, headers: auth_headers(manager))
      end

      it "creates a draft without translations or ticket types" do
        expect(response).to have_http_status(:created)
        body = response.parsed_body["data"]
        expect(body["status"]).to eq("draft")
        expect(body["event_translations"]).to eq([])
        expect(body["ticket_types"]).to eq([])
        expect(body["time_zone"]).to eq("Europe/Kyiv")
      end
    end

    context "when a ticket type has no quantity" do
      before { post_event({ ticket_types: [ { name: "Дорослий", price: 0, total_quantity: 0 } ] }) }

      it "returns validation errors" do
        expect(response).to have_http_status(422)
        expect(response.parsed_body["code"]).to eq("VALIDATION_ERROR")
        expect(response.parsed_body["details"].map { |detail| detail["field"] }).to include("ticket_types[0].total_quantity")
      end
    end

    context "when the event ends before it starts" do
      before { post_event({ start_at: "2026-12-01T12:00:00Z", end_at: "2026-12-01T10:00:00Z" }) }

      it "returns a validation error" do
        expect(response).to have_http_status(422)
        expect(response.parsed_body["details"].map { |detail| detail["field"] }).to include("end_at")
      end
    end

    context "when the request has no token" do
      it "returns unauthorized" do
        post path, params: { event: {} }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the user is not a member" do
      before { post_event({}, headers: auth_headers(create(:user))) }

      it "returns forbidden" do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the organization is not approved" do
      let(:organization) { create(:organization, status: "pending_approval", approved_at: nil) }

      before { post_event({}) }

      it "returns forbidden" do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the organization does not exist" do
      it "returns not found" do
        post "/api/v1/organizations/0/events", params: { event: {} }, headers: auth_headers(owner), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
