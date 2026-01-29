# frozen_string_literal: true

class Libri::DeletionsController < ApplicationController
  def create
    @ids = params[:libro_ids]
    @libri = current_account.libri.where(id: @ids)
    count = @libri.size

    @libri.destroy_all

    flash[:notice] = "#{helpers.pluralize(count, 'libro eliminato', 'libri eliminati')}"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: @ids.map { |id| turbo_stream.remove("libro_#{id}") }
      end
      format.html { redirect_to libri_path }
    end
  end
end
