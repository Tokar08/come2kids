# frozen_string_literal: true

FactoryBot.define do
  factory :order_item do
    order { nil }
    ticket_type { nil }
    quantity { 1 }
    unit_price { 1 }
  end
end
