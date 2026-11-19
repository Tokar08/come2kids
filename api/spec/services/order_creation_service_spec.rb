# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderCreationService, type: :service do
  let(:user) { create(:user) }
  let(:event) { create(:event, :published) }
  let(:ticket_type) do
    create(:ticket_type, event: event, price: 250, currency: 'UAH', total_quantity: 10, sold_quantity: 2)
  end

  def call_service(quantity: 2, idempotency_key: 'order-idem-001', target_event: event, target_ticket: ticket_type)
    described_class.new(
      user: user,
      event: target_event,
      ticket_type_id: target_ticket.id,
      quantity: quantity,
      idempotency_key: idempotency_key
    ).call
  end

  describe '#call' do
    context 'with valid paid ticket reservation' do
      it 'creates a pending order with 15-minute reservation' do
        expect { call_service }
          .to change(Order, :count).by(1)
          .and change(OrderItem, :count).by(1)
          .and change { ticket_type.reload.sold_quantity }.by(2)

        order = Order.last
        expect(order).to be_pending
        expect(order.total_amount).to eq(500)
        expect(order.currency).to eq('UAH')
        expect(order.reserved_until).to be_within(5.seconds).of(15.minutes.from_now)
      end
    end

    context 'with free tickets (price = 0)' do
      it 'creates a paid order without reserved_until' do
        free_ticket = create(:ticket_type, event: event, price: 0, total_quantity: 10, sold_quantity: 0)
        order = call_service(target_ticket: free_ticket)

        expect(order).to be_paid
        expect(order.total_amount).to eq(0)
        expect(order.reserved_until).to be_nil
      end
    end

    context 'when idempotency_key was already used' do
      it 'returns existing order without creating a duplicate' do
        existing = create(:order, user: user, event: event, status: 'pending', idempotency_key: 'dup-key')

        expect { call_service(idempotency_key: 'dup-key') }.not_to change(Order, :count)
        expect(call_service(idempotency_key: 'dup-key')).to eq(existing)
      end
    end

    context 'when event is not published' do
      it 'raises EventNotPublishedError' do
        draft_event = create(:event, :draft)

        expect { call_service(target_event: draft_event) }
          .to raise_error(described_class::EventNotPublishedError)
      end
    end

    context 'when quantity is zero or negative' do
      it 'raises InvalidQuantityError' do
        expect { call_service(quantity: 0) }.to raise_error(described_class::InvalidQuantityError)
      end
    end

    context 'when requested quantity exceeds available tickets' do
      it 'raises TicketsSoldOutError without mutating sold_quantity' do
        expect { call_service(quantity: 9) }.to raise_error(described_class::TicketsSoldOutError)
        expect(ticket_type.reload.sold_quantity).to eq(2)
      end
    end
  end
end
