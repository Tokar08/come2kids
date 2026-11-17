# frozen_string_literal: true

FactoryBot.define do
  factory :event_translation do
    association :event
    locale { 'uk' }
    sequence(:title) { |n| "Подія #{n}" }
    description { 'Опис події' }

    trait :en do
      locale { 'en' }
      sequence(:title) { |n| "Event #{n}" }
    end
  end
end
