class AccountMembers::BulkMembershipScuoleController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_membership

  # POST - Assegna scuole in blocco (per zona, comune, o lista)
  def create
    scuole = filtered_scuole
    existing_ids = @membership.scuola_ids

    new_records = scuole.reject { |s| existing_ids.include?(s.id) }.map do |scuola|
      { membership_id: @membership.id, scuola_id: scuola.id, created_at: Time.current, updated_at: Time.current }
    end

    Accounts::MembershipScuola.insert_all(new_records) if new_records.any?

    @membership.reload

    respond_to do |format|
      format.turbo_stream { render_member_replacement }
      format.html { redirect_to configurazione_path }
    end
  end

  # DELETE - Rimuovi scuole in blocco
  def destroy
    scuole = filtered_scuole
    @membership.membership_scuole.where(scuola: scuole).delete_all

    @membership.reload

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

  def filtered_scuole
    scope = Current.account.scuole
    scope = scope.where(provincia: params[:provincia]) if params[:provincia].present?
    scope = scope.where(grado: params[:grado]) if params[:grado].present?
    scope = scope.where(comune: params[:comune]) if params[:comune].present?
    scope = scope.where(id: params[:scuola_ids]) if params[:scuola_ids].present?
    scope
  end

  def render_member_replacement
    # insert_all/delete_all skip callbacks, broadcast manually
    @membership.broadcast_refresh_later_to(@membership, "scuole")

    render turbo_stream: turbo_stream.replace(
      dom_id(@membership),
      partial: "account_members/member",
      locals: { membership: @membership }
    )
  end
end
