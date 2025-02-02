module Searches
  class ClientableController < ApplicationController
    def index
      @results = case params[:type]
                when 'Cliente'
                  current_user.clienti.search(params[:query])
                when 'ImportScuola'
                  current_user.import_scuole.search(params[:query])
                end

      render partial: 'results', locals: { results: @results }
    end

    # def show
    # end

    # def new
      
    # end
  end
end
