module Accounts
  class DistribuzioneController < ApplicationController
    before_action :require_admin!

    def show
      @memberships = Current.account.memberships.includes(:user).where.not(role: :owner).order(:role, :created_at)

      result = Current.account.distribuzione_scuole
      @non_assegnate         = result[:non_assegnate]
      @non_assegnate_grouped = result[:non_assegnate_grouped]
      @scuole_by_membership  = result[:scuole_by_membership]
    end

    private

    def require_admin!
      redirect_to account_root_path, alert: "Accesso non autorizzato" unless Current.admin?
    end
  end
end
