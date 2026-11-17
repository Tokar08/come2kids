# frozen_string_literal: true

module Api
  class OrganizationBlueprint < Blueprinter::Base
    identifier :id

    fields :slug, :city, :logo_url

    field :name do |organization|
      organization.organization_translations.find { |t| t.locale == I18n.locale.to_s }&.name
    end
  end
end
