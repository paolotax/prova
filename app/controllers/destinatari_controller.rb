# Controller per ricerca unificata destinatari appunti
# Usato dalla combobox multi-entità (Scuola, Cliente, Classe, Persona)
#
# Restituisce risultati nel formato hw-combobox con type evidenziato
#
class DestinatariController < ApplicationController
  include DestinatariHelper

  def index
    @destinatari = search_appuntabili(params[:q])

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def search_appuntabili(query)
    query = sanitize_query(query)
    return [] if query.blank? || query.length < 2

    limit = 6
    results = []

    # Scuole
    Current.account.scuole
      .search_all_word(query)
      .limit(limit)
      .each do |record|
        results << Destinatario.new(record, "Scuola")
      end

    # Clienti
    Current.account.clienti
      .search_all_word(query)
      .limit(limit)
      .each do |record|
        results << Destinatario.new(record, "Cliente")
      end

    # Classi
    Current.account.classi
      .search_all_word(query)
      .includes(:scuola)
      .limit(limit)
      .each do |record|
        results << Destinatario.new(record, "Classe")
      end

    # Persone
    Current.account.persone
      .where("cognome ILIKE :q OR nome ILIKE :q", q: "%#{query}%")
      .includes(:scuola)
      .limit(limit)
      .each do |record|
        results << Destinatario.new(record, "Persona")
      end

    results.first(limit * 3)
  end

  # Rimuove prefisso "[Entity] " e trattini isolati dalla query
  # Es. "[Classe] DANTE ALIGHIERI - " -> "DANTE ALIGHIERI"
  def sanitize_query(query)
    return query if query.blank?

    query.to_s
      .sub(/\A\[[^\]]+\]\s*/, "")  # Rimuove [Entity]
      .gsub(/\s*-\s*$/, "")         # Rimuove trattino finale
      .gsub(/\s+-\s+/, " ")         # Sostituisce " - " con spazio
      .strip
  end
end
