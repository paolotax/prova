module Scuole
  class ScartateController < ApplicationController
    before_action :set_scuola

    def create
      @scuola.scartate.create!(user: Current.user, account: Current.account)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to scuola_path(@scuola) }
      end
    end

    def destroy
      @scuola.scartate.find_by(user: Current.user)&.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to scuola_path(@scuola) }
      end
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end
  end
end
