# frozen_string_literal: true

module Api
  class TicketTypeBlueprint < Blueprinter::Base
    identifier :id

    fields :name, :price, :currency, :total_quantity, :sold_quantity

    field :sale_start_at do |ticket_type|
      ticket_type.sale_start_at&.utc&.iso8601(3)
    end

    field :sale_end_at do |ticket_type|
      ticket_type.sale_end_at&.utc&.iso8601(3)
    end
  end
end
