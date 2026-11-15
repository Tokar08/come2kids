# frozen_string_literal: true

FactoryBot.define do
  factory :category do
    sequence(:slug) { |n| "category-#{n}" }
    sequence(:name_uk) { |n| "Категорія #{n}" }
    sequence(:name_en) { |n| "Category #{n}" }
    sequence(:position) { |n| n }
  end
end
