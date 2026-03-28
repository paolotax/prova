# frozen_string_literal: true

class Libri::BulkUpdatesController < ApplicationController
  # PATCH /libri/bulk_updates - aggiorna campi multipli sui libri selezionati
  def update
    @libri = current_account.libri.where(id: params[:libro_ids])

    update_params = libro_params.to_h.compact_blank

    if update_params.empty?
      redirect_to libri_path, alert: "Nessun campo da aggiornare"
      return
    end

    updated_count = @libri.update_all(update_params)
    @libri.reload

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "#{updated_count} libri aggiornati"
      end
      format.html { redirect_to libri_path, notice: "#{updated_count} libri aggiornati" }
    end
  end

  private

  def libro_params
    params.permit(:editore_id, :categoria_id, :classe, :disciplina, :collana)
  end
end
