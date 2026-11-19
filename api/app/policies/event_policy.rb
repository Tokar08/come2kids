# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  def create?
    organization = organization_for(record)
    return false unless organization&.approved?

    organization_member?(record)
  end
end
