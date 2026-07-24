# Chips combobox per le Classe VERE dell'account. NON confondere con
# ClasseChipsController, che risolve Views::Classe (id diversi: usarlo qui
# mostrerebbe chip di classi sbagliate). Etichetta breve (1A): il contesto
# scuola è già nel modal che ospita la combobox.
class ClassiChipsController < ApplicationController
  def create
    classi = Current.account.classi.find(params[:combobox_values].to_s.split(","))
    chips = classi.map { |c| OpenStruct.new(id: c.id, to_combobox_display: c.nome_breve) }

    render turbo_stream: helpers.combobox_selection_chips_for(chips)
  end
end
