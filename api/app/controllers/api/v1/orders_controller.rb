module Api
  module V1
    class OrdersController < ApplicationController
      # Метод create обробляє POST-запити на створення замовлення
      def create
        event = Event.find(params[:event_id])

        # Викликаємо наш Service Object
        service = OrderCreationService.new(
          user: current_user, # Надається вашою системою авторизації (JWT)
          event: event,
          ticket_type_id: params[:ticket_type_id],
          quantity: params[:quantity],
          idempotency_key: request.headers['Idempotency-Key']
        )

        begin
          order = service.call
          
          # Якщо транзакція успішна, повертаємо статус 201 (Created)
          render json: order, status: :created
          
        rescue OrderCreationService::TicketsSoldOutError => e
          # Помилка: немає вільних місць -> статус 422 (Unprocessable Entity)
          render json: { code: 'EVENT_SOLD_OUT', message: e.message }, status: :unprocessable_entity
        rescue ActiveRecord::RecordNotFound => e
          render json: { code: 'NOT_FOUND', message: e.message }, status: :not_found
        end
      end
    end
  end
end