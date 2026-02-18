class TitoliController < ApplicationController
  before_action :authenticate_user!

  def show
    @codice_isbn = params[:codice_isbn]
    @edizione = EdizioneTitolo.find_by(codice_isbn: @codice_isbn)
    @libro = Current.account.libri.find_by(codice_isbn: @codice_isbn)

    # Info base dal primo record disponibile
    @import_adozione = ImportAdozione.find_by(CODICEISBN: @codice_isbn)

    # Le mie adozioni account-scoped per questo ISBN
    @mie_adozioni = Current.account.adozioni
      .where(codice_isbn: @codice_isbn)
      .includes(classe: :scuola)

    # Dati concorrenza dalla zona (import_adozioni globali)
    codici_scuola = Current.account.scuole
      .where.not(codice_ministeriale: [nil, ""])
      .pluck(:codice_ministeriale)

    # Stesso ISBN nella zona - quante sezioni lo adottano
    @adozioni_zona = ImportAdozione
      .where(CODICEISBN: @codice_isbn, CODICESCUOLA: codici_scuola, DAACQUIST: "Si")

    # Concorrenti: stessa disciplina + classe, solo da acquistare, ISBN diverso nella zona
    if @import_adozione
      @concorrenti = ImportAdozione
        .where(
          DISCIPLINA: @import_adozione.DISCIPLINA,
          ANNOCORSO: @import_adozione.ANNOCORSO,
          CODICESCUOLA: codici_scuola,
          DAACQUIST: "Si"
        )
        .where.not(CODICEISBN: @codice_isbn)
        .group(:CODICEISBN, :TITOLO, :EDITORE)
        .select(:CODICEISBN, :TITOLO, :EDITORE,
          Arel.sql('COUNT(DISTINCT "CODICESCUOLA" || \'_\' || "ANNOCORSO" || \'_\' || "SEZIONEANNO") AS sezioni_count'))
        .order(Arel.sql('sezioni_count DESC'))
    end
  end
end
