# frozen_string_literal: true

class Column::Summary
  attr_reader :column, :account

  def initialize(column, account:)
    @column = column
    @account = account
  end

  def grouped_entries
    @grouped_entries ||= entries.group_by(&:destinatario)
  end

  # Returns { libro => { causale => quantita_con_segno } } sorted by titolo
  def volumi
    @volumi ||= begin
      docs = documenti_non_consegnati
      result = Hash.new { |h, k| h[k] = Hash.new(0) }
      docs.each do |doc|
        segno = doc.movimento == "entrata" ? -1 : 1
        doc.righe.each { |r| result[r.libro][doc.causale] += r.quantita * segno }
      end
      result.sort_by { |libro, _| libro&.titolo.to_s }
    end
  end

  # Causali presenti nei volumi, ordinate per priorita
  def volumi_causali
    @volumi_causali ||= documenti_non_consegnati.map(&:causale).compact.uniq
                          .sort_by(&:priorita)
  end

  def adozioni_per_scuola
    @adozioni_per_scuola ||= begin
      ids = scuola_ids
      return {} if ids.empty?
      Adozione.where(account: account).mie.da_acquistare_flag.per_scuole(ids)
              .includes(classe: :scuola).group_by(&:scuola)
    end
  end

  def entries_count
    entries.size
  end

  private

  def entries
    @entries ||= Entry.load_entryables(
      account.entries.non_ssk.active.in_column(column)
             .with_golden_first.recent
             .includes(:goldness, :closure, :not_now)
    )
  end

  def documenti_non_consegnati
    @documenti_non_consegnati ||= entries
      .select { |e| e.entryable_type == "Documento" }
      .map(&:entryable).compact.reject(&:consegnato?)
  end

  def scuola_ids
    grouped_entries.keys.compact.flat_map { |d|
      case d
      when Scuola then [d.id]
      when Classe then [d.scuola_id]
      else []
      end
    }.uniq
  end
end
