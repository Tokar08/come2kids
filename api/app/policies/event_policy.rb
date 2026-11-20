# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  EDITABLE_STATUSES = %w[draft rejected].freeze

  def create?
    organization = organization_for(record)
    return false unless organization&.approved?

    organization_member?(record)
  end

  def update?
    editable_event?
  end

  def manage_media?
    editable_event?
  end

  def submit?
    create?
  end

  def revise?
    return false unless organization_for(record)&.approved?
    return false unless organization_member?(record)

    record.published?
  end

  private

  def editable_event?
    organization = organization_for(record)
    return false unless organization&.approved?
    return false unless organization_member?(record)

    EDITABLE_STATUSES.include?(record.status)
  end
end
