module Clienti
  class EntriesController < ApplicationController
    layout false

    def show
      @cliente = current_account.clienti.find(params[:cliente_id])
      @entries = Entry.load_entryables(@cliente.open_entries)
    end
  end
end
