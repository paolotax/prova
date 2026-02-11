class MandatiController < ApplicationController
  before_action :authenticate_user!
  before_action :find_editore

  def index
    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")
  end

  def select_editori
    @gruppi = Editore.order(:gruppo).select(:gruppo).distinct
    @editori = Editore.where(gruppo: @gruppo&.gruppo)
                      .order(:editore)
                      .select(:id, :editore).distinct
  end

  def create
    return if params[:hgruppo].blank?

    if params[:heditore].present?
      @mandato = Current.account.mandati.build(editore_id: params[:heditore].to_i)
      @mandato.save!
    else
      Editore.where(gruppo: params[:hgruppo]).find_each do |editore|
        Current.account.mandati.find_or_create_by!(editore: editore)
      end
    end

    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to mandati_path, notice: "Editore assegnato!" }
    end
  rescue ActiveRecord::RecordNotUnique
    flash[:error] = "Mandato già esistente!"
    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")
  end

  def destroy
    @mandato = Current.account.mandati.find(params[:id])
    @mandato.destroy!

    @mandati = Current.account.mandati.includes(:editore).order("editori.editore")

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to mandati_path, notice: "Editore eliminato." }
    end
  end

  private

  def find_editore
    @gruppo  = Editore.where(gruppo: params[:gruppo].presence).first
    @editore = Editore.where(id: params[:id].presence).first
  end
end
