class MandatiController < ApplicationController
  before_action :authenticate_user!

  def index
    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")
  end

  def select_editori
    editori_con_adozioni = editori_da_adozioni
    @gruppi = editori_con_adozioni.select(:gruppo).distinct.order(:gruppo)
    @editori = if params[:gruppo].present?
                 editori_con_adozioni.where(gruppo: params[:gruppo]).order(:editore)
               else
                 []
               end
  end

  def create
    return if params[:hgruppo].blank?

    editore_ids = if params[:heditore].present?
                    [params[:heditore].to_i]
                  else
                    editori_da_adozioni.where(gruppo: params[:hgruppo]).pluck(:id)
                  end

    zone = Current.account.account_zone.where(stato: "attiva")
    zone_ids = Array(params[:zone_ids]).reject(&:blank?)

    editore_ids.each do |eid|
      if zone_ids.any?
        zone.where(id: zone_ids).find_each do |zona|
          Current.account.mandati.find_or_create_by!(
            editore_id: eid,
            provincia: zona.provincia,
            grado: zona.grado
          )
        end
      else
        Current.account.mandati.find_or_create_by!(editore_id: eid)
      end
    end

    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to configurazione_path, notice: "Editore assegnato!" }
    end
  rescue ActiveRecord::RecordNotUnique
    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")
  end

  def aggiorna_mie_adozioni
    UpdateMieAdozioniJob.perform_later(Current.account)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: [] }
      format.html { redirect_to configurazione_path, notice: "Aggiornamento adozioni in corso..." }
    end
  end

  def toggle_disdetta
    @mandato = Current.account.mandati.find(params[:id])
    @mandato.update!(disdetta: !@mandato.disdetta)

    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to configurazione_path }
    end
  end

  def destroy
    @mandato = Current.account.mandati.find(params[:id])
    @mandato.destroy!

    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to configurazione_path, notice: "Editore eliminato." }
    end
  end

  private

  def editori_da_adozioni
    nomi = Adozione.where(account_id: Current.account.id).select(:editore).distinct.pluck(:editore)
    Editore.where(editore: nomi)
  end
end
