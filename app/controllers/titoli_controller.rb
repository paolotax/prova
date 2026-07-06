class TitoliController < ApplicationController
  before_action :authenticate_user!

  def show
    @codice_isbn = params[:codice_isbn]
    @edizione = EdizioneTitolo.find_by(codice_isbn: @codice_isbn)
    @libro = Current.account.libri.find_by(codice_isbn: @codice_isbn)

    # Info base dal primo record disponibile
    @import_adozione = Miur::Adozione.per_anno("202526").find_by(codiceisbn: @codice_isbn)

    # Le mie adozioni: admin vede tutto l'account, member solo le sue scuole
    scuola_ids = Current.admin? ? Current.account.scuola_ids : Current.membership.scuola_ids
    @mie_adozioni = Current.account.adozioni
      .where(codice_isbn: @codice_isbn)
      .where(classe: { scuola_id: scuola_ids })
      .includes(classe: :scuola)

    # Dati concorrenza dalla zona (scuole visibili all'utente)
    codici_scuola = Current.account.scuole
      .where(id: scuola_ids)
      .where.not(codice_ministeriale: [nil, ""])
      .pluck(:codice_ministeriale)

    # Classifica: stesso ISBN + concorrenti, raggruppati per classe/disciplina/tipo_scuola
    if @import_adozione
      @classifica = Miur::Adozione.per_anno("202526")
        .joins(:import_scuola)
        .where(
          disciplina: @import_adozione.disciplina,
          annocorso: @import_adozione.annocorso,
          codicescuola: codici_scuola,
          daacquist: "Si"
        )
        .group(:codiceisbn, :titolo, :editore,
          Arel.sql('import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"'))
        .select(:codiceisbn, :titolo, :editore,
          Arel.sql('import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" AS tipo_scuola_raw'),
          Arel.sql('COUNT(DISTINCT miur_adozioni.codicescuola || \'_\' || miur_adozioni.annocorso || \'_\' || miur_adozioni.sezioneanno) AS sezioni_count'),
          Arel.sql('COUNT(DISTINCT CASE WHEN miur_adozioni.nuovaadoz = \'Si\' THEN miur_adozioni.codicescuola || \'_\' || miur_adozioni.annocorso || \'_\' || miur_adozioni.sezioneanno END) AS nuove_count'))
        .order(Arel.sql('sezioni_count DESC'))

      @superiore = !%w[EE MM].include?(@import_adozione.tipogradoscuola)
    end
  end
end
