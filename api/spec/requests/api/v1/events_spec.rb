# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Events: public catalog', type: :request do
  let(:organization) { create(:organization) }
  let(:category) { create(:category) }

  def publish_event(attrs = {})
    event = create(:event, { organization: organization, category: category }.merge(attrs))
    create(:event_translation, event: event)
    event
  end

  path '/api/v1/events' do
    get 'List published events' do
      tags 'Events'
      description 'Only published events of approved organizations; events of blocked organizations are hidden.'
      produces 'application/json'
      parameter name: :q, in: :query, type: :string, required: false, description: 'Search in the title'
      parameter name: :locale, in: :query, type: :string, required: false, description: 'uk (default) or en'
      parameter name: :category_id, in: :query, type: :integer, required: false
      parameter name: :city, in: :query, type: :string, required: false
      parameter name: :organization_id, in: :query, type: :integer, required: false
      parameter name: :location_type, in: :query, type: :string, required: false, enum: Event::LOCATION_TYPES
      parameter name: :date_from, in: :query, type: :string, format: 'date-time', required: false
      parameter name: :date_to, in: :query, type: :string, format: 'date-time', required: false
      parameter name: :sort, in: :query, type: :string, required: false, enum: %w[date created]
      parameter name: :direction, in: :query, type: :string, required: false, enum: %w[asc desc]
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :pageSize, in: :query, type: :integer, required: false, getter: :page_size, description: 'Up to 100'

      response '200', 'events' do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       title: { type: :string, nullable: true },
                       status: { type: :string },
                       start_at: { type: :string, format: 'date-time', nullable: true },
                       category: { type: :object, nullable: true },
                       organization: { type: :object }
                     }
                   }
                 },
                 pagination: { '$ref' => '#/components/schemas/pagination' }
               },
               required: %w[data pagination]

        context 'when the catalog is empty' do
          run_test! { expect(json['data']).to eq([]) }
        end

        context 'when statuses are mixed' do
          before do
            publish_event
            create(:event, :draft, organization: organization)
            create(:event, :cancelled, organization: organization)
            blocked = create(:organization, status: 'blocked', blocked_at: Time.current, block_reason: 'spam')
            create(:event, organization: blocked)
          end

          run_test!('returns only published events of approved organizations') do
            expect(json['data'].size).to eq(1)
          end
        end

        context 'with a category filter' do
          let(:category_id) { category.id }

          before do
            publish_event
            publish_event(category: create(:category))
          end

          run_test! { expect(json['data'].size).to eq(1) }
        end

        context 'with a city filter' do
          let(:city) { 'Lviv' }

          before do
            publish_event(city: 'Kyiv')
            publish_event(city: 'Lviv')
          end

          run_test! { expect(json['data'].size).to eq(1) }
        end

        context 'with location_type=online' do
          let(:location_type) { 'online' }

          before do
            publish_event
            online = create(:event, :online, organization: organization, category: category)
            create(:event_translation, event: online)
          end

          run_test! { expect(json['data'].size).to eq(1) }
        end

        context 'with date_from' do
          let(:date_from) { 5.days.from_now.iso8601 }

          before do
            publish_event(start_at: 2.days.from_now, end_at: 2.days.from_now + 2.hours)
            publish_event(start_at: 10.days.from_now, end_at: 10.days.from_now + 2.hours)
          end

          run_test! { expect(json['data'].size).to eq(1) }
        end

        context 'with a Ukrainian text search' do
          let(:q) { 'малювання' }
          let(:locale) { 'uk' }

          before do
            event = create(:event, organization: organization, category: category)
            create(:event_translation, event: event, title: 'Майстер-клас з малювання')
            publish_event
          end

          run_test! { expect(json['data'].size).to eq(1) }
        end

        context 'with an English text search' do
          let(:q) { 'Painting' }
          let(:locale) { 'en' }

          before do
            create(:event_translation, :en, event: publish_event, title: 'Painting workshop')
            publish_event
          end

          run_test! { expect(json['data'].size).to eq(1) }
        end

        context 'with sort=date and direction=desc' do
          let(:sort) { 'date' }
          let(:direction) { 'desc' }

          before do
            publish_event(start_at: 1.day.from_now, end_at: 1.day.from_now + 2.hours)
            publish_event(start_at: 3.days.from_now, end_at: 3.days.from_now + 2.hours)
          end

          run_test! do
            expect(json['data'].first['start_at'] > json['data'].last['start_at']).to be(true)
          end
        end

        context 'with pagination' do
          let(:page_size) { 2 }
          let(:page) { 1 }

          before { 3.times { publish_event } }

          run_test! do
            expect(json['data'].size).to eq(2)
            expect(json['pagination']).to include('totalCount' => 3, 'totalPages' => 2)
          end
        end
      end

      response '400', 'invalid query parameters' do
        schema '$ref' => '#/components/schemas/error'

        {
          'an oversized page size' => { page_size: 999 },
          'an unknown sort column' => { sort: 'password' },
          'an invalid direction' => { direction: 'sideways' },
          'an invalid date' => { date_from: 'not-a-date' },
          'an invalid location type' => { location_type: 'hybrid' }
        }.each do |label, query|
          context "with #{label}" do
            query.each { |name, value| let(name) { value } }

            run_test! { expect(json['code']).to eq('BAD_REQUEST') }
          end
        end
      end
    end
  end
end
