# Lettura account-scoped del diff di un import MIUR (design
# 2026-07-08-miur-import-runs-review-design.md). Il diff persistito resta
# MIUR-globale; qui si filtra alle scuole dell'account e si arricchisce con:
#   - classificazione righe (veri cambi vs spostamenti, via ImportDiffRiga.classifica)
#   - stato promossa (regola canonica ControlloAdozioni::Classificazione, mai duplicata)
#   - province per il fan-out reconcile (formato scuole ACCOUNT, es. "MI":
#     il Reconciler filtra su scuole.provincia dell'account, NON sul nome MIUR)
class Miur::RettificheAccount
  def initialize(run:, account:)
    @run = run
    @account = account
  end

  attr_reader :run, :account

  # Run (adozioni) che toccano almeno una scuola dell'account: l'index nasconde gli altri.
  def self.run_ids(account)
    codici = account.scuole.where.not(codice_ministeriale: [nil, ""])
                    .distinct.pluck(:codice_ministeriale)
    Miur::ImportDiffScuola.where(codicescuola: codici).distinct.pluck(:import_run_id)
  end

  def scuole_toccate
    @scuole_toccate ||= run.diff_scuole.where(codicescuola: codici_account).to_a
  end

  # Rollup "esistente" ordinati: promosse prima (sono le "da rettificare"),
  # poi veri cambi desc — in cima ciò che richiede un'azione.
  def esistenti
    @esistenti ||= scuole_toccate.select { |s| s.categoria == "esistente" }
      .sort_by { |s| [promossa?(s.codicescuola) ? 0 : 1, -veri_cambi(s.codicescuola)] }
  end

  def nuove   = scuole_toccate.select { |s| s.categoria == "nuova" }
  def sparite = scuole_toccate.select { |s| s.categoria == "sparita" }

  # {codicescuola => {aggiunte:, rimosse:, spostate:}} per le scuole toccate.
  def classificate
    @classificate ||= run.diff_righe.where(codicescuola: scuole_toccate.map(&:codicescuola))
      .order(:annocorso, :sezioneanno, :disciplina)
      .group_by(&:codicescuola)
      .transform_values { |righe| Miur::ImportDiffRiga.classifica(righe) }
  end

  def veri_cambi(codice)
    c = classificate[codice]
    c ? c[:aggiunte].size + c[:rimosse].size : 0
  end

  def spostamenti(codice)
    classificate[codice]&.fetch(:spostate)&.size || 0
  end

  # Totali per la card di sintesi.
  def totale_aggiunte    = classificate.values.sum { |c| c[:aggiunte].size }
  def totale_rimosse     = classificate.values.sum { |c| c[:rimosse].size }
  def totale_spostamenti = classificate.values.sum { |c| c[:spostate].size }

  def promossa?(codice) = promosse.include?(codice)

  # Province (formato account, es. "MI") delle scuole PROMOSSE toccate:
  # il fan-out reconcile copre solo queste.
  def province_promosse
    scuole_account.values_at(*promosse.to_a).compact
                  .map(&:provincia).compact.uniq.sort
  end

  # {codice_ministeriale => Scuola} per denominazione/provincia/grado/link scheda.
  def scuole_account
    @scuole_account ||= account.scuole
      .where(codice_ministeriale: scuole_toccate.map(&:codicescuola))
      .index_by(&:codice_ministeriale)
  end

  private

  def codici_account
    @codici_account ||= account.scuole.where.not(codice_ministeriale: [nil, ""])
                               .distinct.pluck(:codice_ministeriale)
  end

  # Codici delle scuole toccate già promosse (classi attive dell'anno del run).
  # Unica query, regola canonica di Classificazione (pattern di #conta).
  def promosse
    @promosse ||= begin
      cl = ControlloAdozioni::Classificazione.new(anno: run.anno_scolastico)
      account.scuole
             .where(codice_ministeriale: scuole_toccate.map(&:codicescuola))
             .where(ActiveRecord::Base.sanitize_sql([cl.promossa("scuole"), anno: run.anno_scolastico]))
             .pluck(:codice_ministeriale).to_set
    end
  end
end
