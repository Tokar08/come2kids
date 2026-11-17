# frozen_string_literal: true

class AddTrigramIndexToEventTranslationsTitle < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')
    add_index :event_translations, :title,
              using: :gin, opclass: :gin_trgm_ops,
              name: 'index_event_translations_on_title_trgm'
  end
end
