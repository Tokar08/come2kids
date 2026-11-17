# frozen_string_literal: true

module Api
  module V1
    module Auth
      class ResetPasswordsController < ApplicationController
        skip_after_action :verify_authorized

        def create
          token = params.require(:token)
          password = params.require(:password)
          password_confirmation = params[:password_confirmation]

          Accounts::ResetPassword.call(token, password, password_confirmation)

          render json: { message: I18n.t('auth.password_reset_success') }, status: :ok
        rescue ActionController::ParameterMissing => e
          render json: { code: 'PARAMETER_MISSING', message: e.message }, status: :bad_request
        rescue ActiveRecord::RecordInvalid => e
          render json: {
            message: I18n.t('api_errors.validation_error'),
            code: 'VALIDATION_ERROR',
            details: e.record.errors.map { |err| { field: err.attribute, error: err.type } }
          }, status: :unprocessable_content
        rescue ApiError => e
          render json: { code: e.code.to_s.upcase }, status: e.status || :unprocessable_content
        end
      end
    end
  end
end
