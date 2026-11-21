# frozen_string_literal: true

module Api
  class TicketBlueprint < Blueprinter::Base
    identifier :id
    fields :code, :qr_token, :status

    field :issued_at do |ticket|
      ticket.issued_at&.utc&.iso8601(3)
    end
  end
end