# frozen_string_literal: true

module Api
  module V1
    class OrdersController < ApplicationController
      def create
        event = Event.find(params[:event_id])

        service = OrderCreationService.new(
          user: current_user,
          event: event,
          ticket_type_id: params[:ticket_type_id],
          quantity: params[:quantity],
          idempotency_key: request.headers['Idempotency-Key']
        )

        begin
          order = service.call

          render json: order, status: :created

        rescue OrderCreationService::TicketsSoldOutError => e
          render json: { code: 'EVENT_SOLD_OUT', message: e.message }, status: :unprocessable_entity
        rescue ActiveRecord::RecordNotFound => e
          render json: { code: 'NOT_FOUND', message: e.message }, status: :not_found
        end
      end
    end
  end
end
