class FornitoriController < ApplicationController

  before_action :authenticate_user!
  before_action :set_fornitore, only: %i[ show ]
  before_action :remember_page, only: [:index, :show]

  def index
    scope = Current.account.clienti.fornitori
    @fornitori = params[:search].present? ? scope.search_all_word(params[:search]) : scope
    @fornitori = @fornitori.order(:denominazione)
  end

  def show
    @documenti = @fornitore.documenti.solo_padri.order(data_documento: :desc)
  end

  private

    def set_fornitore
      @fornitore = Current.account.clienti.fornitori.find(params[:id])
    end

end
