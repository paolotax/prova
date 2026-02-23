module Accounts
  class MembersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    def create
      user = User.find_or_initialize_by(email: invitation_email)

      if user.new_record?
        base_name = invitation_email.split("@").first
        user.name = if User.exists?(name: base_name)
          "#{base_name}-#{SecureRandom.hex(3)}"
        else
          base_name
        end
        user.save!
      end

      @membership = Current.account.memberships.find_or_initialize_by(user: user)

      if @membership.new_record?
        @membership.role = :member
        @membership.save!

        # Invalida magic link precedenti e crea nuovo
        user.magic_links.where(purpose: :sign_in).valid.update_all(expires_at: Time.current)
        magic_link = user.magic_links.create!(purpose: :sign_in)
        MagicLinkMailer.invitation(user, magic_link, Current.account).deliver_later
      end

      @members = load_members

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to configurazione_path, notice: "Invito inviato a #{user.email}" }
      end
    end

    def update
      @membership = Current.account.memberships.find(params[:id])

      if @membership.owner?
        redirect_to configurazione_path, alert: "Non puoi modificare il ruolo del proprietario"
        return
      end

      @membership.update!(role: params.dig(:membership, :role))

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to configurazione_path }
      end
    end

    def destroy
      @membership = Current.account.memberships.find(params[:id])

      if @membership.owner?
        redirect_to configurazione_path, alert: "Non puoi rimuovere il proprietario"
        return
      end

      if @membership == Current.membership
        redirect_to configurazione_path, alert: "Non puoi rimuovere te stesso"
        return
      end

      @membership.destroy!

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to configurazione_path, notice: "Utente rimosso" }
      end
    end

    private

    def require_admin!
      unless Current.admin?
        redirect_to account_root_path, alert: "Accesso non autorizzato"
      end
    end

    def invitation_email
      params.require(:email).strip.downcase
    end

    def load_members
      Current.account.memberships.includes(:user, :scuole).order(role: :desc, created_at: :asc)
    end
  end
end
