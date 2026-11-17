# frozen_string_literal: true

module Api
  class EventBlueprint < Blueprinter::Base
    identifier :id

    fields :time_zone, :location_type, :address, :city, :online_url, :banner_url, :status

    field :title do |event|
      event.event_translations.find { |t| t.locale == I18n.locale.to_s }&.title
    end

    field :start_at do |event|
      event.start_at&.utc&.iso8601(3)
    end

    field :end_at do |event|
      event.end_at&.utc&.iso8601(3)
    end

    association :category, blueprint: Api::CategoryBlueprint
    association :organization, blueprint: Api::OrganizationBlueprint
  end
end
