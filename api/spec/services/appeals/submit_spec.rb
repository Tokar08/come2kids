# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Appeals::Submit do
  subject(:result) { described_class.call(user: user, target: user, message: message) }

  let(:user) { create(:user, :blocked, blocked_at: 1.day.ago) }
  let(:message) { 'It was a mistake.' }

  it 'returns Success with the open appeal and logs it' do
    expect { result }.to change(ModerationLog, :count).by(1)

    expect(result).to be_success
    expect(result.value!).to have_attributes(status: 'open', target: user, submitted_by: user)
  end

  context 'when an appeal is already open' do
    before { create(:appeal, target: user) }

    it 'returns Failure with APPEAL_ALREADY_OPEN' do
      expect(result.failure.code).to eq('APPEAL_ALREADY_OPEN')
    end
  end

  context 'when the last appeal was rejected less than 24 hours ago' do
    before { create(:appeal, :rejected, target: user, reviewed_at: 1.hour.ago) }

    it 'returns Failure with APPEAL_COOLDOWN and the time a new appeal is allowed' do
      expect(result.failure.code).to eq('APPEAL_COOLDOWN')
      expect(result.failure.details.first[:field]).to eq('next_appeal_allowed_at')
    end
  end

  context 'when the message is too long' do
    let(:message) { 'a' * 2001 }

    it 'returns Failure with VALIDATION_FAILED and creates nothing' do
      expect { result }.not_to change(Appeal, :count)

      expect(result.failure.code).to eq('VALIDATION_FAILED')
    end
  end
end
