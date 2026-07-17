module Adozioni
  class RimatchesController < ApplicationController
    def create
      anno = params[:anno_scolastico].presence || "202627"
      Comunicate::Matcher.rimatch!(account: Current.account, anno_scolastico: anno)
      redirect_to adozioni_comunicate_path(anno_scolastico: anno), notice: "Matching rieseguito"
    end
  end
end
