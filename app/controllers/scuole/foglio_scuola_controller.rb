# frozen_string_literal: true

module Scuole
  class FoglioScuolaController < ApplicationController
    def show
      scuola = current_account.scuole.find(params[:scuola_id])
      tipo_stampa = params[:tipo_stampa] || "mie_adozioni"
      con_sovrapacchi = params[:con_sovrapacchi] == "true"

      pdf = FoglioScuolaPdf.new(
        [scuola],
        view: view_context,
        tipo_stampa: tipo_stampa,
        con_sovrapacchi: con_sovrapacchi
      )

      send_data pdf.render,
                filename: "foglio_#{scuola.denominazione.parameterize}_#{Time.current.to_i}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end
  end
end
