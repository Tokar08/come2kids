# frozen_string_literal: true

require "rails_helper"

RSpec.describe TicketType do
  subject(:ticket_type) { build(:ticket_type, event: event) }

  let(:event) { create(:event, :draft) }

  it "is valid with a free ticket and a positive quantity" do
    expect(ticket_type).to be_valid
  end

  it "defaults currency to UAH and sold quantity to zero" do
    record = described_class.create!(event: event, name: "Child", price: 0, total_quantity: 5)

    expect(record.currency).to eq("UAH")
    expect(record.sold_quantity).to eq(0)
  end

  it "rejects a blank name" do
    ticket_type.name = ""

    expect(ticket_type).not_to be_valid
    expect(ticket_type.errors[:name]).to be_present
  end

  it "rejects a negative price" do
    ticket_type.price = -1

    expect(ticket_type).not_to be_valid
    expect(ticket_type.errors[:price]).to be_present
  end

  it "rejects a quantity that is not greater than zero" do
    ticket_type.total_quantity = 0

    expect(ticket_type).not_to be_valid
    expect(ticket_type.errors[:total_quantity]).to be_present
  end

  it "rejects a sold quantity above the total" do
    ticket_type.total_quantity = 2
    ticket_type.sold_quantity = 3

    expect(ticket_type).not_to be_valid
    expect(ticket_type.errors[:sold_quantity]).to be_present
  end
end
