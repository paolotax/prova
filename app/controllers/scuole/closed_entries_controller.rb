module Scuole
  class ClosedEntriesController < ApplicationController
    layout false

    def show
      @scuola = Current.account.scuole.find(params[:scuola_id])
      @closed_entries = Entry.load_entryables(@scuola.closed_entries)
    end
  end
end
