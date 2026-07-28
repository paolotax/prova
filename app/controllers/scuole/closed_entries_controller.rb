module Scuole
  class ClosedEntriesController < ApplicationController
    include HasVista

    layout false

    def show
      @scuola = Current.account.scuole.find(params[:scuola_id])
      @closed_entries = Entry.load_entryables(@scuola.closed_entries)
      @vista = resolve_vista
    end
  end
end
