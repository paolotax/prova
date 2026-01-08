module Passwordless
  class SessionsController < ApplicationController
    before_action :set_session, only: [:destroy]

    # GET /sessions
    def index
      @sessions = current_user.sessions.active.order(last_active_at: :desc)
      @current_session = current_session
    end

    # DELETE /sessions/:id
    def destroy
      if @session == current_session
        redirect_to passwordless_sessions_path, alert: "Non puoi terminare la sessione corrente da qui."
        return
      end

      @session.revoke!
      redirect_to passwordless_sessions_path, notice: "Sessione terminata."
    end

    # DELETE /sessions/destroy_all
    def destroy_all
      current_user.revoke_other_sessions!(current_session)
      redirect_to passwordless_sessions_path, notice: "Tutte le altre sessioni sono state terminate."
    end

    # DELETE /logout
    def logout
      current_session&.revoke!
      cookies.delete(:session_token)

      Current.user = nil
      Current.session = nil
      Current.account = nil
      Current.membership = nil

      redirect_to new_magic_link_path, notice: "Disconnesso con successo."
    end

    private

    def set_session
      @session = current_user.sessions.find(params[:id])
    end
  end
end
