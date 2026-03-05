module Scuole
  module Classi
    class EntriesController < ApplicationController
      layout false

      def show
        @classe = Current.account.scuole.find(params[:scuola_id]).classi.find(params[:classe_id])
        @entries = Entry.load_entryables(@classe.open_entries)
      end
    end
  end
end
