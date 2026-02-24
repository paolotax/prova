module Accounts
  class MandatiController < ApplicationController
    before_action :authenticate_user!

    def index
      @mandati = mandati_ordinati
    end

    def new
      editori_con_adozioni = Current.account.editori_da_adozioni
      @gruppi = editori_con_adozioni.select(:gruppo).distinct.order(:gruppo)
      @editori = if params[:gruppo].present?
                   editori_con_adozioni.where(gruppo: params[:gruppo]).order(:editore)
                 else
                   []
                 end
    end

    def create
      return if params[:hgruppo].blank?

      editore_ids = Current.account.editore_ids_per_mandato(
        gruppo: params[:hgruppo],
        editore_id: params[:heditore]
      )

      zone_ids = Array(params[:zone_ids]).reject(&:blank?).presence

      Current.account.crea_mandati_per_editori!(editore_ids, zone_ids: zone_ids)

      @mandati = mandati_ordinati
      editori_con_adozioni = Current.account.editori_da_adozioni
      @gruppi = editori_con_adozioni.select(:gruppo).distinct.order(:gruppo)
      @editori = []

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to accounts_configurazione_path, notice: "Editore assegnato!" }
      end
    rescue ActiveRecord::RecordNotUnique
      @mandati = mandati_ordinati
    end

    def update
      @mandato = Current.account.mandati.find(params[:id])
      @mandato.update!(mandato_params)
      redirect_to accounts_mandati_path
    end

    def destroy
      Current.account.mandati.find(params[:id]).destroy!

      @mandati = mandati_ordinati

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to accounts_configurazione_path, notice: "Editore eliminato." }
      end
    end

    private

    def mandati_ordinati
      Current.account.mandati.includes(:editore)
        .order("editori.gruppo, editori.editore")
    end

    def mandato_params
      params.require(:mandato).permit(:area)
    end
  end
end
