# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderCreationService, type: :service do
  subject(:call_service) { described_class.new(**params).call }

  let(:user) { create(:user) }
  let(:event) { create(:event, :published) }
  let(:ticket_type) do
    create(:ticket_type, event: event, price: 250, currency: 'UAH', total_quantity: 10, sold_quantity: 2)
  end
  let(:quantity) { 2 }
  let(:idempotency_key) { 'order-idem-001' }
  let(:params) do
    {
      user: user,
      event: event,
      ticket_type_id: ticket_type.id,
      quantity: quantity,
      idempotency_key: idempotency_key
    }
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
      let(:ticket_type) do
        create(:ticket_type, event: event, price: 0, total_quantity: 10, sold_quantity: 0)
      end

      it 'creates a paid order without reserved_until' do
        order = call_service

        expect(order).to be_paid
        expect(order.total_amount).to eq(0)
        expect(order.reserved_until).to be_nil
      end
    end

    context 'when idempotency_key was already used' do
      let!(:existing_order) do
        create(:order, user: user, event: event, status: 'pending', idempotency_key: idempotency_key)
      end

      it 'returns existing order without creating a duplicate' do
        expect { call_service }.not_to change(Order, :count)
        expect(call_service).to eq(existing_order)
      end
    end

    context 'when event is not published' do
      let(:event) { create(:event, :draft) }

      it 'raises EventNotPublishedError' do
        expect { call_service }.to raise_error(described_class::EventNotPublishedError)
      end
    end

    context 'when quantity is zero or negative' do
      let(:quantity) { 0 }

      it 'raises InvalidQuantityError' do
        expect { call_service }.to raise_error(described_class::InvalidQuantityError)
      end
    end

    context 'when requested quantity exceeds available tickets' do
      let(:quantity) { 9 }

      it 'raises TicketsSoldOutError without mutating sold_quantity' do
        expect { call_service }.to raise_error(described_class::TicketsSoldOutError)
        expect(ticket_type.reload.sold_quantity).to eq(2)
      end
    end
  end
end