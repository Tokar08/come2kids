# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: { title: "Come2Kids API", version: "v1" },
      servers: [ { url: "http://localhost:3000" } ],
      components: {
        securitySchemes: {
          bearerAuth: { type: :http, scheme: :bearer, bearerFormat: "JWT" }
        },
        schemas: {
          error: {
            type: :object,
            properties: {
              code: { type: :string, example: 'UNAUTHORIZED' },
              message: { type: :string },
              details: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    field: { type: :string },
                    error: { type: :string },
                    message: { type: :string }
                  }
                }
              }
            },
            required: %w[code]
          },
          eventMedia: {
            type: :object,
            properties: {
              id: { type: :integer },
              kind: { type: :string, enum: %w[banner gallery] },
              position: { type: :integer },
              url: { type: :string },
              content_type: { type: :string },
              byte_size: { type: :integer }
            },
            required: %w[id kind position url content_type byte_size]
          },
          eventMediaResponse: {
            type: :object,
            properties: { data: { '$ref' => '#/components/schemas/eventMedia' } },
            required: %w[data]
          },
          eventMediaList: {
            type: :object,
            properties: {
              data: { type: :array, items: { '$ref' => '#/components/schemas/eventMedia' } }
            },
            required: %w[data]
          },
          eventImageOrder: {
            type: :object,
            properties: {
              image_ids: { type: :array, items: { type: :integer } }
            },
            required: %w[image_ids]
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
