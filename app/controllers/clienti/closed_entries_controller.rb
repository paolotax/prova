module Clienti
  class ClosedEntriesController < ApplicationController
    def show
      @cliente = current_account.clienti.find(params[:cliente_id])
      presenter = Clienti::Presenter.new(@cliente)
      @closed_entries = Entry.load_entryables(presenter.closed_entries)
    end
  end
end
