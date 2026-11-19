# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::CatalogQuery, type: :model do
  let(:organization) { create(:organization) }

  def publish_event(attrs = {})
    create(:event, { organization: organization }.merge(attrs))
  end

  describe '.call' do
    context 'when statuses are mixed' do
      before do
        publish_event
        publish_event(status: 'draft')
        blocked = create(:organization, status: 'blocked', blocked_at: Time.current, block_reason: 'spam')
        create(:event, organization: blocked)
      end

      it 'returns only published approved events' do
        expect(described_class.call({}).count).to eq(1)
      end
    end

    context 'with invalid location type' do
      it 'raises application error' do
        expect { described_class.call({ location_type: 'hybrid' }) }
          .to raise_error(Api::ApplicationError)
      end
    end

    context 'with invalid date' do
      it 'raises application error' do
        expect { described_class.call({ date_from: 'nope' }) }
          .to raise_error(Api::ApplicationError)
      end
    end
  end
end
