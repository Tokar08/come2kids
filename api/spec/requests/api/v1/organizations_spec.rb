# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Organizations', type: :request do
  path '/api/v1/organizations' do
    post 'Requests organization creation' do
      tags 'Organizations'
      consumes 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer token'

      parameter name: :organization, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Come2Kids Events' },
          description: { type: :string, example: 'Organizing the best events' },
          contact_email: { type: :string, example: 'contact@example.com' }
        },
        required: %w[name contact_email]
      }

      response '201', 'Organization request created successfully' do
        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{JwtService.encode(user)}" }
        let(:organization) { { name: 'New Org', description: 'Test desc', contact_email: 'neworg@example.com' } }

        run_test!
      end

      response '422', 'Validation failed or user is already an owner' do
        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{JwtService.encode(user)}" }
        let(:organization) { { name: '', description: 'Test desc', contact_email: 'x@example.com' } }

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:organization) { { name: 'New Org', description: 'Test desc', contact_email: 'x@example.com' } }

        run_test!
      end
    end
  end
end