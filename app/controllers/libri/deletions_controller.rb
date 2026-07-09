# frozen_string_literal: true

class Libri::DeletionsController < ApplicationController
  def create
    @ids = params[:ids]
    @libri = current_account.libri.where(id: @ids)

    # Elimina righe orfane (senza documento_righe) per non bloccare la cancellazione
    orphan_righe = Riga.where(libro_id: @libri.select(:id))
                       .where.missing(:documento_righe)
    orphan_righe.delete_all

    deletable = @libri.where.missing(:righe)
    skipped_count = @libri.size - deletable.size
    deleted_ids = deletable.pluck(:id)

    deletable.destroy_all

    if skipped_count > 0 && deleted_ids.any?
      flash[:notice] = "#{helpers.pluralize(deleted_ids.size, 'libro eliminato', 'libri eliminati')}. #{helpers.pluralize(skipped_count, 'libro non eliminato perché usato in documenti', 'libri non eliminati perché usati in documenti')}."
    elsif skipped_count > 0
      flash[:alert] = "#{helpers.pluralize(skipped_count, 'libro non eliminato perché usato in documenti', 'libri non eliminati perché usati in documenti')}."
    else
      flash[:notice] = "#{helpers.pluralize(deleted_ids.size, 'libro eliminato', 'libri eliminati')}."
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: deleted_ids.map { |id| turbo_stream.remove("libro_#{id}") }
      end
      format.html { redirect_to libri_path }
    end
  end
end
