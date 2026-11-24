# frozen_string_literal: true

class EventReview < ApplicationRecord
  belongs_to :event
  belongs_to :user

  validates :rating, presence: true, numericality: { only_integer: true, in: 1..5 }
  validates :user_id, uniqueness: { scope: :event_id }
end
