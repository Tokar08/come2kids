# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventPolicy do
  subject(:policy) { described_class.new(user, event) }

  let(:organization) { create(:organization) }
  let(:event) { build(:event, :draft, organization: organization) }
  let(:user) { nil }

  describe "#create?" do
    context "when the user owns the approved organization" do
      let(:user) { create(:company_member, :owner, organization: organization).user }

      it "allows the draft" do
        expect(policy.create?).to be(true)
      end
    end

    context "when the user manages the approved organization" do
      let(:user) { create(:company_member, :manager, organization: organization).user }

      it "allows the draft" do
        expect(policy.create?).to be(true)
      end
    end

    context "when the user belongs to another organization" do
      let(:user) { create(:company_member, :owner).user }

      it "denies the draft" do
        expect(policy.create?).to be(false)
      end
    end

    context "when the user has no organization" do
      let(:user) { create(:user) }

      it "denies the draft" do
        expect(policy.create?).to be(false)
      end
    end

    context "when the caller is a guest" do
      it "denies the draft" do
        expect(policy.create?).to be(false)
      end
    end

    context "when the organization is not approved" do
      let(:organization) { create(:organization, status: "pending_approval", approved_at: nil) }
      let(:user) { create(:company_member, :owner, organization: organization).user }

      it "denies the draft" do
        expect(policy.create?).to be(false)
      end
    end

    context "when the organization is blocked" do
      let(:organization) do
        create(:organization, status: "blocked", approved_at: nil, blocked_at: Time.current, block_reason: "spam")
      end
      let(:user) { create(:company_member, :owner, organization: organization).user }

      it "denies the draft" do
        expect(policy.create?).to be(false)
      end
    end
  end
end
