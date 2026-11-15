# frozen_string_literal: true

class OrderCreationService
  class EventNotPublishedError < StandardError; end
  class TicketsSoldOutError < StandardError; end

  def initialize(user:, event:, ticket_type_id:, quantity:, idempotency_key: nil)
    @user = user
    @event = event
    @ticket_type_id = ticket_type_id
    @quantity = quantity.to_i
    @idempotency_key = idempotency_key
  end

  def call
    if @idempotency_key.present?
      existing_order = Order.find_by(idempotency_key: @idempotency_key)
      return existing_order if existing_order
    end


    Order.transaction do
      ticket_type = TicketType.lock.find(@ticket_type_id)

      if ticket_type.sold_quantity + @quantity > ticket_type.total_quantity
        raise TicketsSoldOutError, 'Not enough tickets available'
      end


      total_amount = ticket_type.price * @quantity
      status = total_amount.zero? ? 'paid' : 'pending'


      reserved_until = status == 'pending' ? 15.minutes.from_now : nil

      order = Order.create!(
        user: @user,
        event: @event,
        total_amount: total_amount,
        currency: ticket_type.currency,
        status: status,
        idempotency_key: @idempotency_key,
        reserved_until: reserved_until
      )

      order.order_items.create!(
        ticket_type_id: ticket_type.id,
        quantity: @quantity,
        unit_price: ticket_type.price
      )


      ticket_type.update!(sold_quantity: ticket_type.sold_quantity + @quantity)


      order
    end
  end
end
