# frozen_string_literal: true

module Organizations
  class Create
    include Dry::Monads[:result]

    def self.call(user:, name:, description:, contact_email:)
      new(user: user, name: name, description: description, contact_email: contact_email).call
    end

    def initialize(user:, name:, description:, contact_email:)
      @user = user
      @name = name.to_s.strip
      @description = description.to_s.strip
      @contact_email = contact_email.to_s.strip
    end

    def call
      return Failure(:already_owner) if user_already_owner?

      organization = Organization.new(
        slug: generate_slug,
        contact_email: @contact_email,
        status: 'pending_approval'
      )

      translation = organization.organization_translations.build(
        locale: I18n.locale,
        name: @name,
        description: @description
      )

      if organization.valid? && translation.valid?
        organization.save!
        assign_owner_role(organization)
        Success(organization)
      else
        organization.errors.merge!(translation.errors)

        Rails.logger.info("VALIDATION FAILED. Errors: #{organization.errors.full_messages}")

        Failure(organization.errors)
      end
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    private

    def generate_slug
      base = @name.presence || SecureRandom.hex(4)
      base.parameterize
    end

    def user_already_owner?
      @user.company_members.joins(:role).exists?(roles: { key: 'owner' })
    end

    def assign_owner_role(organization)
      owner_role = Role.find_by(key: 'owner')
      raise 'Owner role not found! Please seed the database.' unless owner_role

      CompanyMember.create!(
        user: @user,
        organization: organization,
        role: owner_role
      )
    end
  end
end
