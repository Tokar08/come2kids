FactoryBot.define do
  factory :order do
    user { nil }
    event { nil }
    total_amount { 1 }
    currency { "MyString" }
    status { "MyString" }
    idempotency_key { "MyString" }
    reserved_until { "2026-11-13 13:34:45" }
  end
end
