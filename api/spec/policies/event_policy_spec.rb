# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventPolicy do
  subject(:policy) { described_class.new(user, event) }

  let(:organization) { create(:organization) }
  let(:event) { create(:event, :draft, organization: organization) }
  let(:user) { create(:company_member, :owner, organization: organization).user }

  it 'allows the owner of an approved organization to change a draft' do
    expect(policy.manage_media?).to be(true)
  end

  it 'allows a manager of the same organization' do
    manager = create(:company_member, :manager, organization: organization).user

    expect(described_class.new(manager, event).manage_media?).to be(true)
  end

  it 'allows a rejected event' do
    event.update!(status: 'rejected')

    expect(policy.manage_media?).to be(true)
  end

  it 'denies an event that is under review, published, or cancelled' do
    %w[under_review published cancelled].each do |status|
      event.update!(status: status)

      expect(policy.manage_media?).to be(false)
    end
  end

  it 'denies a member of another organization' do
    outsider = create(:company_member, :owner).user

    expect(described_class.new(outsider, event).manage_media?).to be(false)
  end

  it 'denies a user who is not a member' do
    expect(described_class.new(create(:user), event).manage_media?).to be(false)
  end

  it 'denies a guest' do
    expect(described_class.new(nil, event).manage_media?).to be(false)
  end

  it 'denies an organization that is not approved' do
    organization.update!(status: 'pending_approval', approved_at: nil)

    expect(policy.manage_media?).to be(false)
  end

  it 'denies a blocked organization' do
    organization.update!(status: 'blocked', blocked_at: Time.current, block_reason: 'spam')

    expect(policy.manage_media?).to be(false)
  end
end
