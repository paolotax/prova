module Adozioni
  class DistribuzioniController < ApplicationController
    def create
      comunicata = Comunicata.for_account(Current.account).find(params[:id])

      if Comunicate::Matcher.new(comunicata).distribuisci!
        redirect_to adozioni_comunicate_path(anno_scolastico: comunicata.anno_scolastico),
                    notice: "Alunni distribuiti su #{comunicata.sezioni}"
      else
        redirect_to adozioni_comunicate_path(anno_scolastico: comunicata.anno_scolastico),
                    alert: "Impossibile distribuire: classi mancanti per #{comunicata.sezioni}"
      end
    end
  end
end
