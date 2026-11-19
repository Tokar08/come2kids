# frozen_string_literal: true

class CreateTicketTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_types do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, limit: 200, null: false
      t.integer :price, null: false, default: 0
      t.string :currency, limit: 3, null: false, default: "UAH"
      t.integer :total_quantity, null: false
      t.integer :sold_quantity, null: false, default: 0
      t.datetime :sale_start_at
      t.datetime :sale_end_at
      t.timestamps

      t.check_constraint "price >= 0", name: "chk_ticket_types_price"
      t.check_constraint "total_quantity > 0", name: "chk_ticket_types_total_quantity"
      t.check_constraint "sold_quantity >= 0 AND sold_quantity <= total_quantity", name: "chk_ticket_types_sold_within_total"
    end
  end
end
