module Clienti
  class ClosedEntriesController < ApplicationController
    include HasVista

    layout false

    def show
      @cliente = current_account.clienti.find(params[:cliente_id])
      @closed_entries = Entry.load_entryables(@cliente.closed_entries)
      @vista = resolve_vista
    end
  end
end
