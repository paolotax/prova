module Scuole
  module Persone
    class ClasseChipsController < ApplicationController
      def create
        @classi = Classe.where(id: params[:combobox_values].split(","))
        render turbo_stream: helpers.combobox_selection_chips_for(@classi, display: :nome_breve)
      end
    end
  end
end
