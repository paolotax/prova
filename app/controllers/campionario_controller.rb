class CampionarioController < ApplicationController

  before_action :authenticate_user!

  def show
    @campionario = Current.user.documenti.includes(righe: :libro).find(params[:id])

    # Trova la causale "Campionario Resa"
    causale_resa = Causale.find_by(causale: "Campionario Resa")

    # Cerca la resa con stesso numero documento e data documento
    @resa = Current.user.documenti.includes(righe: :libro).where(
      causale_id: causale_resa&.id,
      numero_documento: @campionario.numero_documento,
      data_documento: @campionario.data_documento,
      clientable_id: @campionario.clientable_id,
      clientable_type: @campionario.clientable_type
    ).first

    # Prepara i dati per il confronto
    # Creo una struttura con tutti i libri presenti in campionario e/o resa
    campionario_righe = @campionario.righe.to_a.index_by(&:libro_id)
    resa_righe = @resa&.righe&.to_a&.index_by(&:libro_id) || {}

    # Unisco tutti i libro_id
    libro_ids = (campionario_righe.keys + resa_righe.keys).uniq.compact

    @confronto = libro_ids.map do |libro_id|
      {
        libro: campionario_righe[libro_id]&.libro || resa_righe[libro_id]&.libro,
        riga_campionario: campionario_righe[libro_id],
        riga_resa: resa_righe[libro_id]
      }
    end.compact.sort_by { |row| row[:libro]&.titolo || "" }
  end

end
