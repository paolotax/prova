module Accounts
  module Members
    class BulkMembershipScuoleController < ApplicationController
      include ActionView::RecordIdentifier

      before_action :authenticate_user!
      before_action :require_admin!
      before_action :set_membership

      # POST - Assegna scuole in blocco (per zona, comune, o lista)
      def create
        scuole = filtered_scuole.to_a
        @membership.assegna_scuole!(scuole)

        respond_to do |format|
          format.turbo_stream { render_member_replacement }
          format.html { redirect_to accounts_configurazione_path }
        end
      end

      # DELETE - Rimuovi scuole in blocco
      def destroy
        scuole = filtered_scuole.to_a
        @membership.rimuovi_scuole!(scuole)

        respond_to do |format|
          format.turbo_stream { render_member_replacement }
          format.html { redirect_to accounts_configurazione_path }
        end
      end

      private

      def require_admin!
        unless Current.admin?
          redirect_to account_root_path, alert: "Accesso non autorizzato"
        end
      end

      def set_membership
        @membership = Current.account.memberships.find(params[:member_id])
      end

      def filtered_scuole
        scope = Current.account.scuole
        scope = scope.where(provincia: params[:provincia]) if params[:provincia].present?
        scope = scope.where(grado: params[:grado]) if params[:grado].present?
        scope = scope.where(comune: params[:comune]) if params[:comune].present?
        scope = scope.where(area: params[:area]) if params[:area].present?
        scope = scope.where(id: params[:scuola_ids]) if params[:scuola_ids].present?
        scope
      end

      def render_member_replacement
        # insert_all/delete_all skip callbacks, broadcast manually
        @membership.broadcast_refresh_later_to(@membership, "scuole")

        render turbo_stream: turbo_stream.replace(
          dom_id(@membership),
          partial: "accounts/members/member",
          locals: { membership: @membership }
        )
      end
    end
  end
end
