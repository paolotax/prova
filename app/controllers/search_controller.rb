class SearchController < ApplicationController
  def index
    @import_scuole = current_user.import_scuole.order(:DENOMINAZIONESCUOLA).search_all_word(params[:query])
    @libri = current_user.libri.order(:titolo).search_all_word(params[:query])
    @clienti = current_user.clienti.order(:denominazione).search(params[:query])
  end
end
