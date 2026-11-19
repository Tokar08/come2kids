# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  EDITABLE_STATUSES = %w[draft rejected].freeze

  def manage_media?
    organization = organization_for(record)
    return false unless organization&.approved?
    return false unless organization_member?(record)

    EDITABLE_STATUSES.include?(record.status)
  end
end
