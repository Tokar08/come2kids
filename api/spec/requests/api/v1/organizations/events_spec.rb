# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::Organizations::Events", type: :request do
  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:organization_id) { organization.id }
  let(:Authorization) { "Bearer #{JwtService.encode(owner)}" } # rubocop:disable RSpec/VariableName

  path "/api/v1/organizations/{organization_id}/events" do
    post "Create a draft event" do
      tags "Organization events"
      description "Creates an event in draft for an approved organization. " \
                  "Status, author, currency and sold quantity are set by the server."
      security [ bearerAuth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :payload, in: :body, schema: { "$ref" => "#/components/schemas/draftEventRequest" }

      response "201", "draft created" do
        schema "$ref" => "#/components/schemas/managedEventResponse"
        let(:payload) do
          category = create(:category)
          {
            event: {
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
          }
        end

        run_test! do |response|
          body = JSON.parse(response.body).fetch("data")

          expect(body["status"]).to eq("draft")
          expect(body["event_translations"]).to contain_exactly(
            a_hash_including("locale" => "uk", "title" => "Майстерня")
          )
          expect(body["ticket_types"]).to contain_exactly(
            a_hash_including(
              "name" => "Дорослий", "price" => 0, "currency" => "UAH",
              "sold_quantity" => 0, "total_quantity" => 20
            )
          )
          expect(Event.last.created_by).to eq(owner)
        end
      end

      response "422", "invalid draft" do
        schema "$ref" => "#/components/schemas/error"
        let(:payload) do
          { event: { ticket_types: [ { name: "Дорослий", price: 0, total_quantity: 0 } ] } }
        end

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["code"]).to eq("VALIDATION_ERROR")
          expect(body["details"].map { |detail| detail["field"] }).to include("ticket_types[0].total_quantity")
        end
      end

      response "401", "missing or invalid token" do
        schema "$ref" => "#/components/schemas/error"
        let(:Authorization) { "Bearer invalid" } # rubocop:disable RSpec/VariableName
        let(:payload) { { event: {} } }

        run_test!
      end

      response "403", "caller cannot create events for this organization" do
        schema "$ref" => "#/components/schemas/error"
        let(:Authorization) { "Bearer #{JwtService.encode(create(:user))}" } # rubocop:disable RSpec/VariableName
        let(:payload) { { event: {} } }

        run_test!
      end

      response "404", "organization not found" do
        schema "$ref" => "#/components/schemas/error"
        let(:organization_id) { 0 }
        let(:payload) { { event: {} } }

        run_test!
      end
    end
  end

  describe "draft rules" do
    def post_event(event = {}, headers: nil)
      post "/api/v1/organizations/#{organization.id}/events",
           params: { event: event }, headers: headers || auth_headers(owner), as: :json
    end

    it "lets a manager save an empty draft" do
      manager = create(:company_member, :manager, organization: organization).user
      post_event({}, headers: auth_headers(manager))

      expect(response).to have_http_status(:created)
      body = response.parsed_body["data"]
      expect(body["status"]).to eq("draft")
      expect(body["event_translations"]).to eq([])
      expect(body["ticket_types"]).to eq([])
      expect(body["time_zone"]).to eq("Europe/Kyiv")
    end

    it "rejects an end time that is not after the start" do
      post_event({ start_at: "2026-12-01T12:00:00Z", end_at: "2026-12-01T10:00:00Z" })

      expect(response).to have_http_status(422)
      expect(response.parsed_body["details"].map { |detail| detail["field"] }).to include("end_at")
    end

    it "rejects a request without a token" do
      post "/api/v1/organizations/#{organization.id}/events", params: { event: {} }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an owner of an organization that is not approved" do
      pending = create(:organization, status: "pending_approval", approved_at: nil)
      member = create(:company_member, :owner, organization: pending).user

      post "/api/v1/organizations/#{pending.id}/events",
           params: { event: {} }, headers: auth_headers(member), as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
