# Risolve i chip della combobox multiselect libri (inserimento multiplo adozioni).
# Gli id sono adozioni-esemplari del catalogo dell'account.
class AdozioneChipsController < ApplicationController
  before_action :set_adozioni

  def create
    render turbo_stream: helpers.combobox_selection_chips_for(@adozioni)
  end

  def create_dismissing
    render turbo_stream: helpers.dismissing_combobox_selection_chips_for(@adozioni)
  end

  private

  def set_adozioni
    @adozioni = Current.account.adozioni.find params[:combobox_values].split(",")
  end
end
