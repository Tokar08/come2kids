# frozen_string_literal: true

module Api
  class EventTranslationBlueprint < Blueprinter::Base
    identifier :id

    fields :locale, :title, :description
  end
end
