# frozen_string_literal: true

FactoryBot.define do
  factory :ticket_type do
    association :event
    sequence(:name) { |n| "Ticket #{n}" }
    price { 0 }
    currency { "UAH" }
    total_quantity { 10 }
    sold_quantity { 0 }
  end
end
