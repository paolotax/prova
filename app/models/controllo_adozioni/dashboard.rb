module ControlloAdozioni
  # Dashboard admin di controllo_adozioni: soli aggregati SQL per provincia
  # (stessi criteri delle righe di Panoramica) + stato assegnazione agenti.
  # Niente materializzazione delle scuole: una query GROUP BY per le righe.
  class Dashboard
    Riga = Struct.new(:provincia, :scuole, :promosse, :da_promuovere, :mancanti_miur, :anomalie,
                      keyword_init: true)
    Agente = Struct.new(:membership, :scuole_count, keyword_init: true)

    def initialize(account:)
      @account = account
    end

    attr_reader :account

    def anno = @anno ||= NewScuola.maximum(:anno_scolastico)

    def righe
      @righe ||= ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql([sql_righe, account_id: account.id, anno: anno.to_s])
      ).map do |r|
        Riga.new(provincia: r["provincia"], scuole: r["scuole"].to_i, promosse: r["promosse"].to_i,
                 da_promuovere: r["da_promuovere"].to_i, mancanti_miur: r["mancanti_miur"].to_i,
                 anomalie: r["anomalie"].to_i)
      end
    end

    def totali
      @totali ||= %i[scuole promosse da_promuovere mancanti_miur anomalie]
        .index_with { |k| righe.sum(&k) }
    end

    def agenti
      @agenti ||= begin
        counts = Accounts::MembershipScuola.joins(:membership)
          .where(memberships: { account_id: account.id }).group(:membership_id).count
        account.memberships.member.includes(:user).map do |m|
          Agente.new(membership: m, scuole_count: counts[m.id].to_i)
        end.sort_by { |a| -a.scuole_count }
      end
    end

    def non_assegnate_count
      @non_assegnate_count ||= account.scuole.where.not(
        id: Accounts::MembershipScuola.joins(:membership)
              .where(memberships: { account_id: account.id }).select(:scuola_id)
      ).count
    end

    private

    # promosse/da_promuovere hanno senso solo con uno snapshot MIUR presente.
    def sql_righe
      promossa = anno.present? ? <<~SQL.strip : "FALSE"
        EXISTS (SELECT 1 FROM classi c WHERE c.scuola_id = sc.id
                AND c.stato = 'attiva' AND c.anno_scolastico >= :anno)
      SQL
      promuovibile = anno.present? ? <<~SQL.strip : "FALSE"
        EXISTS (SELECT 1 FROM new_scuole ns WHERE ns.codice_scuola = sc.codice_ministeriale
                AND ns.anno_scolastico = :anno)
        AND EXISTS (SELECT 1 FROM new_adozioni nae WHERE nae.codicescuola = sc.codice_ministeriale
                    AND nae.tipogradoscuola = 'EE')
        AND NOT EXISTS (SELECT 1 FROM classi c2 WHERE c2.scuola_id = sc.id
                        AND c2.stato = 'attiva' AND c2.anno_scolastico >= :anno)
      SQL

      <<~SQL
        SELECT provincia,
               COUNT(*)                              AS scuole,
               COUNT(*) FILTER (WHERE promossa)      AS promosse,
               COUNT(*) FILTER (WHERE promuovibile)  AS da_promuovere,
               COUNT(*) FILTER (WHERE NOT nel_miur)  AS mancanti_miur,
               COUNT(*) FILTER (WHERE con_anomalie)  AS anomalie
        FROM (
          SELECT sc.provincia,
                 EXISTS (SELECT 1 FROM new_adozioni na
                         WHERE na.codicescuola = sc.codice_ministeriale)          AS nel_miur,
                 EXISTS (SELECT 1 FROM controllo_anomalie ca
                         WHERE ca.codicescuola = sc.codice_ministeriale)          AS con_anomalie,
                 #{promossa}     AS promossa,
                 #{promuovibile} AS promuovibile
          FROM scuole sc
          WHERE sc.account_id = :account_id
            AND COALESCE(sc.codice_ministeriale, '') <> ''
            AND (sc.adozioni_count > 0 OR EXISTS (
                   SELECT 1 FROM new_adozioni nac
                   WHERE nac.codicescuola = sc.codice_ministeriale))
        ) s
        GROUP BY provincia
        ORDER BY provincia
      SQL
    end
  end
end
