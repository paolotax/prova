# frozen_string_literal: true

class Clienti::DeletionsController < ApplicationController
  def create
    @ids = params[:cliente_ids]
    @clienti = current_account.clienti.where(id: @ids)
    count = @clienti.size

    @clienti.destroy_all

    flash[:notice] = "#{helpers.pluralize(count, 'cliente eliminato', 'clienti eliminati')}"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: @ids.map { |id| turbo_stream.remove("cliente_#{id}") }
      end
      format.html { redirect_to clienti_path }
    end
  end
end
