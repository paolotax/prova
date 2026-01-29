# frozen_string_literal: true

class Clienti::BulkTappeController < ApplicationController
  def create
    @clienti = current_account.clienti.where(id: params[:cliente_ids])
    data_tappa = params[:data_tappa]

    @clienti.each do |cliente|
      current_user.tappe.find_or_create_by(
        tappable_type: "Cliente",
        tappable_id: cliente.id,
        data_tappa: data_tappa
      )
    end

    flash[:notice] = "Tappe create per #{@clienti.size} clienti"

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to clienti_path }
    end
  end
end
