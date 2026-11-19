# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  def create?
    !user.company_members.joins(:role).exists?(roles: { key: Role::OWNER })
  end
end
