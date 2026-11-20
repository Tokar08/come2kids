# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  # FR-ORG-2, FR-MOD-5: only staff of an approved, not deleted organization may create events;
  # pending, rejected and blocked organizations cannot.
  def create?
    organization = organization_for(record)
    return false unless organization&.accepts_event_changes?

    organization_member?(record)
  end
end
