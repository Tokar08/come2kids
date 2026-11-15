# frozen_string_literal: true

module Api
  module V1
    class EventsController < ApplicationController
      skip_after_action :verify_authorized

      SORTABLE = { 'date' => 'events.start_at', 'created' => 'events.created_at' }.freeze
      FILTERABLE = {
        category_id: 'events.category_id',
        city: 'events.city',
        organization_id: 'events.organization_id'
      }.freeze

      def index
        apply_requested_locale
        relation = Events::CatalogQuery.call(params, locale: params[:locale].presence || I18n.locale)
        records, pagination = paginate_collection(
          relation,
          sortable: SORTABLE,
          filterable: FILTERABLE,
          default_sort: 'date'
        )
        render_collection(records, blueprint: Api::EventBlueprint, pagination: pagination)
      end

      private

      def apply_requested_locale
        requested = params[:locale].presence
        return if requested.blank?

        locale = requested.to_sym
        I18n.locale = locale if I18n.available_locales.include?(locale)
      end
    end
  end
end
