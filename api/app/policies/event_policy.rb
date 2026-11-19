# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  def create?
    organization = organization_for(record)
    return false unless organization&.approved?

    organization_member?(record)
  end

  def update?
    organization = organization_for(record)
    return false unless organization&.approved?
    return false unless organization_member?(record)

    %w[draft rejected].include?(record.status)
  end

  def submit?
    create?
  end
end
