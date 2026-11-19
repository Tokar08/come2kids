# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    association :organization
    association :created_by, factory: :user
    status { 'published' }
    location_type { 'offline' }
    start_at { 2.days.from_now }
    end_at { 3.days.from_now }

    trait :draft do
      status { 'draft' }
    end

    trait :published do
      status { 'published' }
    end
  end
end