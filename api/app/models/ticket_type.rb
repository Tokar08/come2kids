# frozen_string_literal: true

class TicketType < ApplicationRecord
  CURRENCY = 'UAH'

  belongs_to :event

  validates :name, presence: true, length: { maximum: 200 }
  validates :price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :total_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :sold_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :sold_within_total

  private

  def sold_within_total
    return if sold_quantity.blank? || total_quantity.blank?
    return if sold_quantity <= total_quantity

    errors.add(:sold_quantity, 'must be less than or equal to total quantity')
  end
end
