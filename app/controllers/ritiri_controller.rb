class RitiriController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def show
    # Visibili nel ritiro: righe ancora aperte + rientrate (cosi' le rientrate
    # restano evidenziate e ripristinabili). Le altre chiuse (saggio/venduto/
    # mancante) sono "consumate" dal documento generato e vivono solo nello
    # show della BollaVisione.
    visibili_sql = "bolla_visione_righe.processato_at IS NULL OR bolla_visione_righe.esito = ?"

    @bolle = @scuola.bolle_visione
      .joins(:bolla_visione_righe)
      .where(visibili_sql, BollaVisioneRiga.esiti[:rientrato])
      .includes(:collana)
      .distinct
      .ordered

    @righe_per_bolla = @bolle.each_with_object({}) do |bv, h|
      h[bv] = bv.bolla_visione_righe
        .where(visibili_sql, BollaVisioneRiga.esiti[:rientrato])
        .includes(:libro)
        .order(:position)
    end

    @gruppo_per_libro_e_collana = build_gruppo_lookup(@bolle)
  end

  def rientro
    riga = find_riga
    riga.update!(esito: :rientrato, processato_at: Time.current)
    redirect_to scuola_ritiro_path(@scuola)
  end

  def riapri
    riga = find_riga
    BollaVisioneRiga.transaction do
      doc_riga = riga.documento_riga
      riga.update!(esito: nil, processato_at: nil, documento_riga_id: nil)
      if doc_riga.present?
        documento = doc_riga.documento
        doc_riga.destroy
        documento.destroy if documento.documento_righe.reload.empty?
      end
    end
    target = (params[:return_to] == "ritiro") ? scuola_ritiro_path(@scuola) : bolla_visione_path(riga.bolla_visione)
    redirect_to target
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end

  def find_riga
    Current.account.bolla_visione_righe
      .joins(:bolla_visione)
      .where(bolle_visione: { scuola_id: @scuola.id })
      .find(params[:id])
  end

  def build_gruppo_lookup(bolle)
    collana_ids = bolle.map(&:collana_id).uniq
    CollanaLibro.where(collana_id: collana_ids)
      .pluck(:collana_id, :libro_id, :gruppo)
      .each_with_object({}) { |(c, l, g), h| h[[c, l]] = g }
  end
end
