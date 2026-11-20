# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  EDITABLE_STATUSES = %w[draft rejected].freeze

  # FR-ORG-2, FR-MOD-5: only staff of an approved, not deleted organization may create events;
  # pending, rejected and blocked organizations cannot.
  def create?
    organization = organization_for(record)
    return false unless organization&.accepts_event_changes?

    organization_member?(record)
  end

  # Media can change only while the event is editable and its organization may still change events
  # (approved, not blocked or deleted).
  def manage_media?
    organization = organization_for(record)
    return false unless organization&.accepts_event_changes?
    return false unless organization_member?(record)

    EDITABLE_STATUSES.include?(record.status)
  end
end
