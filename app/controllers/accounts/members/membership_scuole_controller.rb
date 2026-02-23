module Accounts
  module Members
    class MembershipScuoleController < ApplicationController
      include ActionView::RecordIdentifier

      before_action :authenticate_user!
      before_action :require_admin!
      before_action :set_membership

      def create
        scuola = Current.account.scuole.find(params[:scuola_id])
        @membership.membership_scuole.find_or_create_by!(scuola: scuola)

        respond_to do |format|
          format.turbo_stream { render_member_replacement }
          format.html { redirect_to configurazione_path }
        end
      end

      def destroy
        membership_scuola = @membership.membership_scuole.find(params[:id])
        membership_scuola.destroy!

        respond_to do |format|
          format.turbo_stream { render_member_replacement }
          format.html { redirect_to configurazione_path }
        end
      end

      private

      def require_admin!
        unless Current.admin?
          redirect_to account_root_path, alert: "Accesso non autorizzato"
        end
      end

      def set_membership
        @membership = Current.account.memberships.find(params[:account_member_id])
      end

      def render_member_replacement
        @membership.reload
        render turbo_stream: turbo_stream.replace(
          dom_id(@membership),
          partial: "accounts/members/member",
          locals: { membership: @membership }
        )
      end
    end
  end
end
