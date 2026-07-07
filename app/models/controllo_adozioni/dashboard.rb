module ControlloAdozioni
  # Dashboard admin di controllo_adozioni: soli aggregati SQL per provincia
  # (stessi criteri delle righe di Panoramica) + stato assegnazione agenti.
  # Niente materializzazione delle scuole: una query GROUP BY per le righe.
  class Dashboard
    Riga = Struct.new(:provincia, :scuole, :promosse, :da_promuovere, :mancanti_miur, :anomalie,
                      :codici_nuovi, keyword_init: true)
    Agente = Struct.new(:membership, :scuole_count, keyword_init: true)

    def initialize(account:)
      @account = account
    end

    attr_reader :account

    def anno = @anno ||= Miur.anno_corrente

    def righe
      @righe ||= begin
        dr = codici_nuovi_per_provincia
        rows = ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.sanitize_sql([sql_righe, account_id: account.id, anno: anno.to_s])
        ).map do |r|
          Riga.new(provincia: r["provincia"], scuole: r["scuole"].to_i, promosse: r["promosse"].to_i,
                   da_promuovere: r["da_promuovere"].to_i, mancanti_miur: r["mancanti_miur"].to_i,
                   anomalie: r["anomalie"].to_i, codici_nuovi: dr[r["provincia"]])
        end
        # Province con soli codici nuovi (zona appena creata, anagrafe non ancora importata).
        (dr.keys - rows.map(&:provincia)).each do |provincia|
          rows << Riga.new(provincia: provincia, scuole: 0, promosse: 0, da_promuovere: 0,
                           mancanti_miur: 0, anomalie: 0, codici_nuovi: dr[provincia])
        end
        rows.sort_by(&:provincia)
      end
    end

    def totali
      @totali ||= %i[scuole promosse da_promuovere mancanti_miur anomalie codici_nuovi]
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

    # "Codici nuovi": codici in miur_scuole (anno corrente, zone dell'account) con adozioni
    # nel grado della zona ma assenti dall'anagrafe account — la versione contata di
    # Panoramica#cambi_codice, senza matching predecessori. Una query per grado di zona.
    def codici_nuovi_per_provincia
      counts = Hash.new(0)
      return counts if anno.blank?

      account.zone.group_by(&:grado).each do |grado, zone|
        tg = Panoramica::TG[grado] || []
        tipi = TipoScuola.where(grado: grado).pluck(:tipo)
        next if tg.empty? || tipi.empty?

        sql = <<~SQL
          SELECT ns.provincia, COUNT(*) AS n
          FROM miur_scuole ns
          WHERE ns.anno_scolastico = :anno
            AND ns.provincia IN (:province)
            AND ns.tipo_scuola IN (:tipi)
            AND EXISTS (SELECT 1 FROM miur_adozioni na
                        WHERE na.codicescuola = ns.codice_scuola AND na.anno_scolastico = :anno
                          AND na.tipogradoscuola IN (:tg))
            AND NOT EXISTS (SELECT 1 FROM scuole sc
                            WHERE sc.account_id = :account_id
                              AND sc.codice_ministeriale = ns.codice_scuola)
          GROUP BY ns.provincia
        SQL
        ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.sanitize_sql([sql, account_id: account.id, anno: anno,
                                           province: zone.map(&:provincia), tipi: tipi, tg: tg])
        ).each { |r| counts[r["provincia"]] += r["n"].to_i }
      end
      counts
    end

    # promosse/da_promuovere hanno senso solo con uno snapshot MIUR presente.
    def sql_righe
      cl = Classificazione.new(anno: anno)

      <<~SQL
        SELECT provincia,
               COUNT(*)                              AS scuole,
               COUNT(*) FILTER (WHERE promossa)      AS promosse,
               COUNT(*) FILTER (WHERE promuovibile)  AS da_promuovere,
               COUNT(*) FILTER (WHERE NOT nel_miur)  AS mancanti_miur,
               COUNT(*) FILTER (WHERE con_anomalie)  AS anomalie
        FROM (
          SELECT sc.provincia,
                 #{cl.nel_miur}      AS nel_miur,
                 #{cl.con_anomalie}  AS con_anomalie,
                 #{cl.promossa}      AS promossa,
                 #{cl.promuovibile}  AS promuovibile
          FROM scuole sc
          WHERE sc.account_id = :account_id
            AND COALESCE(sc.codice_ministeriale, '') <> ''
            AND (sc.adozioni_count > 0 OR EXISTS (
                   SELECT 1 FROM miur_adozioni nac
                   WHERE nac.codicescuola = sc.codice_ministeriale
                     AND nac.anno_scolastico = :anno))
        ) s
        GROUP BY provincia
        ORDER BY provincia
      SQL
    end
  end
end
