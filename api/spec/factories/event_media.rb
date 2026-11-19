# frozen_string_literal: true

FactoryBot.define do
  factory :event_medium, class: 'EventMedia' do
    association :event, :draft
    kind { 'gallery' }
    sequence(:position)

    after(:build) do |media|
      media.file.attach(
        io: StringIO.new(Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')),
        filename: 'photo.png',
        content_type: 'image/png'
      )
    end

    trait :banner do
      kind { 'banner' }
      position { 0 }
    end
  end
end
