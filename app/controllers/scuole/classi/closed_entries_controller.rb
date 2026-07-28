module Scuole
  module Classi
    class ClosedEntriesController < ApplicationController
      include HasVista

      layout false

      def show
        @classe = Current.account.scuole.find(params[:scuola_id]).classi.find(params[:classe_id])
        @closed_entries = Entry.load_entryables(@classe.closed_entries)
        @vista = resolve_vista
      end
    end
  end
end
