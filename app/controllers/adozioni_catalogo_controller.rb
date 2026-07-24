# Sorgente async della combobox libri per l'inserimento multiplo di adozioni.
# I titoli vengono dalle adozioni dell'account (titoli reali, anche di concorrenza),
# non dal catalogo Libro dell'utente. Un esemplare per ISBN (il piu recente).
class AdozioniCatalogoController < ApplicationController
  before_action :authenticate_user!

  def index
    esemplari = Current.account.adozioni

    # Solo gli ultimi due anni scolastici: titoli freschi e query nel perimetro
    # dell'indice (account_id, anno_scolastico) — l'account piu grande ha ~1M
    # adozioni storiche, senza questo filtro il DISTINCT ON le scandirebbe
    # tutte a ogni battuta.
    if (corrente = AnnoScolastico.corrente)
      esemplari = esemplari.where(anno_scolastico: [corrente.to_s, corrente.precedente.to_s])
    end

    if (anni = anni_corso).present?
      esemplari = esemplari.where(anno_corso: anni)
    end

    if (q = params[:q]).present?
      esemplari = esemplari.where(
        "adozioni.titolo ILIKE :like OR adozioni.codice_isbn LIKE :prefix",
        like: "%#{q}%", prefix: "#{q}%"
      )
    end

    # Un esemplare per ISBN: il piu recente. DISTINCT ON esige l'ORDER BY su isbn,
    # poi ri-ordino per titolo nella query esterna.
    esemplari = esemplari.select("DISTINCT ON (adozioni.codice_isbn) adozioni.*")
                         .order(:codice_isbn, created_at: :desc)

    @adozioni = Adozione.from(esemplari, :adozioni).order(:titolo).limit(25)

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def anni_corso
    params[:anno_corso].to_s.split(",").map(&:strip).reject(&:blank?)
  end
end
