class ControlloAdozioni::PromozioniController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def new
    @anno_target  = anno_target
    @anno_corrente = @scuola.classi.attive.maximum(:anno_scolastico) || precedente(@anno_target)
    @codice_suggerito = codice_nuovo_suggerito
    @quinte_uscenti = @scuola.classi.attive.where(anno_corso: "5").includes(persona_classi: :persona)
    @sezioni_prime = NewAdozione.where(codicescuola: @codice_suggerito.presence || @scuola.codice_ministeriale,
                                       annocorso: "1", tipogradoscuola: "EE").distinct.pluck(:sezioneanno).compact.sort
  end

  def create
    if params[:a].blank?
      redirect_to controllo_adozioni_path(@scuola.codice_ministeriale),
                  alert: "Anno scolastico target mancante."
      return
    end
    nuovo_codice = params[:codice_nuovo].presence
    if nuovo_codice && nuovo_codice != @scuola.codice_ministeriale
      vecchio = @scuola.codice_ministeriale
      @scuola.update!(codice_ministeriale: nuovo_codice,
                      note: [@scuola.note.presence, "ex codice #{vecchio} (#{params[:da]})"].compact.join("\n"))
    end
    spostamenti = params.fetch(:spostamenti, {}).permit!.to_h
    ScuolaPromuoviClassiJob.perform_later(@scuola, da: params[:da], a: params[:a],
                                          spostamenti_insegnanti: spostamenti)
    redirect_to controllo_adozioni_path(@scuola.codice_ministeriale),
                notice: "Passaggio anno avviato per #{@scuola.denominazione}."
  end

  private

  def set_scuola
    @scuola = current_account.scuole.find_by!(codice_ministeriale: params[:codicescuola])
  end

  def anno_target
    NewScuola.maximum(:anno_scolastico).presence || NewAdozione.maximum(:anno_scolastico).presence || "202627"
  end

  def precedente(anno) # "202627" -> "202526"
    return nil if anno.blank? || anno.length != 6
    y1 = anno[0..3].to_i - 1
    "#{y1}#{(y1 + 1).to_s[-2..]}"
  end

  # "certo" = un solo plesso non tracciato in new_scuole, stesso comune e grado EE, con adozioni in new_adozioni.
  def codice_nuovo_suggerito
    sql = <<~SQL
      SELECT DISTINCT ns.codice_scuola
      FROM new_scuole ns
      WHERE ns.comune = $1
        AND ns.anno_scolastico = $2
        AND ns.codice_scuola <> $3
        AND EXISTS (SELECT 1 FROM new_adozioni na WHERE na.codicescuola = ns.codice_scuola AND na.tipogradoscuola = 'EE')
        AND NOT EXISTS (SELECT 1 FROM scuole s WHERE s.account_id = $4 AND s.codice_ministeriale = ns.codice_scuola)
    SQL
    rows = ActiveRecord::Base.connection.exec_query(
      sql, "CodiceSuggerito",
      [
        ActiveRecord::Relation::QueryAttribute.new("comune", @scuola.comune, ActiveRecord::Type::String.new),
        ActiveRecord::Relation::QueryAttribute.new("anno", anno_target, ActiveRecord::Type::String.new),
        ActiveRecord::Relation::QueryAttribute.new("codice_attuale", @scuola.codice_ministeriale, ActiveRecord::Type::String.new),
        ActiveRecord::Relation::QueryAttribute.new("account_id", @scuola.account_id, ActiveRecord::Type::String.new)
      ]
    )
    rows.count == 1 ? rows.first["codice_scuola"] : nil
  end
end
