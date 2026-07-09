# frozen_string_literal: true

class Libri::ConfezioniController < ApplicationController
  # POST /libri/confezioni - crea nuova confezione con libri selezionati come fascicoli
  def create
    @fascicoli = current_account.libri.where(id: params[:ids])

    if @fascicoli.empty?
      redirect_to libri_path, alert: "Seleziona almeno un libro"
      return
    end

    # Prendi il primo fascicolo come base per la confezione
    primo = @fascicoli.first

    @confezione = current_account.libri.create!(
      user_id: current_user.id,
      codice_isbn: generate_confezione_isbn,
      titolo: params[:titolo].presence || "Confezione #{primo.titolo}",
      editore_id: primo.editore_id,
      categoria_id: primo.categoria_id,
      prezzo_in_cents: @fascicoli.sum(&:prezzo_in_cents),
      classe: primo.classe,
      disciplina: primo.disciplina
    )

    @fascicoli.each_with_index do |fascicolo, index|
      ConfezioneRiga.create!(
        confezione: @confezione,
        fascicolo: fascicolo,
        row_order: index
      )
    end

    redirect_to @confezione, notice: "Confezione creata con #{@fascicoli.count} fascicoli"
  end

  private

  def generate_confezione_isbn
    # Genera ISBN alfanumerico univoco per confezioni create da bulk action
    # Formato: CONF-XXXXXX (6 caratteri alfanumerici)
    loop do
      isbn = "CONF-#{SecureRandom.alphanumeric(6).upcase}"
      break isbn unless current_user.libri.exists?(codice_isbn: isbn)
    end
  end
end
