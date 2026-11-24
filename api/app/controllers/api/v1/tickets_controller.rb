# frozen_string_literal: true

module Api
  module V1
    class TicketsController < ApplicationController
      before_action :authenticate_user!

      def my
        authorize Ticket
        tickets, pagination = paginate_collection(
          Ticket.where(user: current_user).includes(:ticket_type),
          sortable: { issued_at: :issued_at, created_at: :created_at, status: :status },
          filterable: { status: :status, event_id: :event_id },
          default_sort: :issued_at
        )

        render_collection tickets, blueprint: Api::TicketBlueprint, pagination: pagination
      end

      def show
        ticket = Ticket.includes(:ticket_type).find(params[:id])
        authorize ticket

        render_resource ticket, blueprint: Api::TicketBlueprint
      end

      def pdf
        ticket = Ticket.includes(:event, :ticket_type, :user).find(params[:id])
        authorize ticket, :pdf?

        result = Tickets::RenderPdf.call(ticket)
        raise result.failure if result.failure?

        response.set_header('Cache-Control', 'private, no-store')
        send_data result.value!, type: 'application/pdf', disposition: 'attachment',
                  filename: "ticket-#{ticket.code}.pdf"
      end
    end
  end
end
