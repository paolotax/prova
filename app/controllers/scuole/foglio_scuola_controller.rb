# frozen_string_literal: true

module Scuole
  class FoglioScuolaController < ApplicationController
    def show
      scuola = current_account.scuole.find(params[:scuola_id])
      tipo_stampa = params[:tipo_stampa] || "mie_adozioni"
      solo_sovrapacchi = params[:solo_sovrapacchi] == "true"

      pdf = FoglioScuolaPdf.new(
        [scuola],
        view: view_context,
        tipo_stampa: tipo_stampa,
        con_sovrapacchi: solo_sovrapacchi,
        solo_sovrapacchi: solo_sovrapacchi
      )

      prefix = solo_sovrapacchi ? "sovrapacchi" : "foglio"
      send_data pdf.render,
                filename: "#{prefix}_#{scuola.denominazione.parameterize}_#{Time.current.to_i}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end
  end
end
