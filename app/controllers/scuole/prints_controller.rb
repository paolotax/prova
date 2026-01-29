# frozen_string_literal: true

module Scuole
  class PrintsController < ApplicationController
    def create
      @scuole = current_account.import_scuole.where(id: params[:ids])

      respond_to do |format|
        format.pdf do
          tipo_stampa = params[:tipo_stampa] || "tutte_adozioni"
          con_sovrapacchi = params[:con_sovrapacchi] == "true"

          pdf = FoglioScuolaPdf.new(
            @scuole,
            view: view_context,
            tipo_stampa: tipo_stampa,
            con_sovrapacchi: con_sovrapacchi
          )

          filename_suffix = tipo_stampa == "mie_adozioni" ? "_mie_adozioni" : ""
          sovrapacchi_suffix = con_sovrapacchi ? "_con_sovrapacchi" : ""
          filename = "fs#{filename_suffix}#{sovrapacchi_suffix}_#{Time.current.to_i}.pdf"

          send_data pdf.render,
                    filename: filename,
                    type: "application/pdf",
                    disposition: "inline"
        end
      end
    end
  end
end
