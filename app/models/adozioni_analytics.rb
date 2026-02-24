class AdozioniAnalytics
  attr_reader :account, :scuola_ids

  def initialize(account:, scuola_ids:)
    @account = account
    @scuola_ids = scuola_ids
  end

  # Tab "Le mie" — my adoptions (mie, da_acquistare), user's schools only
  def mie_adozioni(filtri: {})
    scope = account.adozioni.mie
      .where(da_acquistare: true)
      .joins(classe: :scuola)
      .where(classi: { scuola_id: scuola_ids })

    scope = apply_filtri(scope, filtri)

    scope.group("scuole.grado", :disciplina, :titolo, :editore, :codice_isbn)
      .select(
        "scuole.grado AS grado",
        :disciplina, :titolo, :editore, :codice_isbn,
        "COUNT(DISTINCT adozioni.classe_id) AS sezioni_count",
        "COUNT(DISTINCT adozioni.classe_id) * 18 AS copie_stimate",
        "SUM(CASE WHEN adozioni.disdetta THEN 1 ELSE 0 END) AS disdette_count"
      )
      .order("scuole.grado", :disciplina, Arel.sql("COUNT(DISTINCT adozioni.classe_id) DESC"))
  end

  # Tab "Agenzia" — all account's mie adozioni (includes disdette)
  def agenzia(filtri: {})
    scope = account.adozioni.mie

    scope = apply_filtri(scope, filtri)

    scope.group(:disciplina, :titolo, :editore, :codice_isbn)
      .select(
        :disciplina, :titolo, :editore, :codice_isbn,
        "COUNT(DISTINCT adozioni.classe_id) AS sezioni_count",
        "COUNT(DISTINCT adozioni.classe_id) * 18 AS copie_stimate",
        "SUM(CASE WHEN adozioni.disdetta THEN 1 ELSE 0 END) AS disdette_count"
      )
      .order(:disciplina, Arel.sql("COUNT(DISTINCT adozioni.classe_id) DESC"))
  end

  # Tab "Confronto editori" — from import_adozioni, account's schools
  def confronto_editori(filtri: {})
    codici = account.scuole.where(id: scuola_ids)
      .where.not(codice_ministeriale: [nil, ""])
      .pluck(:codice_ministeriale)

    return [] if codici.empty?

    scope = ImportAdozione.where(CODICESCUOLA: codici, DAACQUIST: "Si")
    scope = apply_filtri_import(scope, filtri)

    scope.group(:EDITORE, :DISCIPLINA, :ANNOCORSO)
      .order(Arel.sql('COUNT(DISTINCT "CODICESCUOLA" || \'_\' || "ANNOCORSO" || \'_\' || "SEZIONEANNO") DESC'))
      .select(
        :EDITORE, :DISCIPLINA, :ANNOCORSO,
        'COUNT(DISTINCT "CODICESCUOLA" || \'_\' || "ANNOCORSO" || \'_\' || "SEZIONEANNO") AS sezioni_count'
      )
  end

  # Tab "Dati provincia" — from import_adozioni, entire province
  def dati_provincia(provincia:, filtri: {})
    scope = ImportAdozione
      .joins("JOIN import_scuole ON import_scuole.\"CODICESCUOLA\" = import_adozioni.\"CODICESCUOLA\"")
      .where(import_scuole: { PROVINCIA: provincia })
      .where(DAACQUIST: "Si")

    scope = apply_filtri_import(scope, filtri)

    scope.group(:EDITORE, :DISCIPLINA, :ANNOCORSO)
      .order(Arel.sql('COUNT(DISTINCT import_adozioni."CODICESCUOLA" || \'_\' || import_adozioni."ANNOCORSO" || \'_\' || import_adozioni."SEZIONEANNO") DESC'))
      .select(
        'import_adozioni."EDITORE"', 'import_adozioni."DISCIPLINA"', 'import_adozioni."ANNOCORSO"',
        'COUNT(DISTINCT import_adozioni."CODICESCUOLA" || \'_\' || import_adozioni."ANNOCORSO" || \'_\' || import_adozioni."SEZIONEANNO") AS sezioni_count'
      )
  end

  # Tab "Dati nazionali" — from import_adozioni, all Italy
  def dati_nazionali(filtri: {})
    scope = ImportAdozione.where(DAACQUIST: "Si")
    scope = apply_filtri_import(scope, filtri)

    scope.group(:EDITORE, :DISCIPLINA, :ANNOCORSO)
      .order(Arel.sql('COUNT(DISTINCT "CODICESCUOLA" || \'_\' || "ANNOCORSO" || \'_\' || "SEZIONEANNO") DESC'))
      .select(
        :EDITORE, :DISCIPLINA, :ANNOCORSO,
        'COUNT(DISTINCT "CODICESCUOLA" || \'_\' || "ANNOCORSO" || \'_\' || "SEZIONEANNO") AS sezioni_count'
      )
  end

  # Available filter options scoped to mie adozioni da_acquistare
  def mie_filter_options
    base = account.adozioni.mie.where(da_acquistare: true)
      .joins(classe: :scuola)
      .where(classi: { scuola_id: scuola_ids })

    {
      discipline: base.distinct.pluck(:disciplina).compact.sort,
      editori: base.distinct.pluck(:editore).compact.sort,
      gruppi: Editore.where(editore: base.distinct.pluck(:editore)).pluck(:gruppo).compact.uniq.sort,
      province: base.joins(classe: :scuola).select("scuole.provincia").distinct.map(&:provincia).compact.sort,
      gradi: base.joins(classe: :scuola).select("scuole.grado").distinct.map(&:grado).compact.sort,
      tipi_scuola: base.joins(classe: :scuola).select("scuole.tipo_scuola").distinct.map(&:tipo_scuola).compact.sort,
      aree: base.joins(classe: :scuola).select("scuole.area").distinct.map(&:area).compact.reject { |a| a.start_with?("__") }.sort
    }
  end

  # Available filter options for all adozioni (other tabs)
  def discipline_options
    account.adozioni.distinct.pluck(:disciplina).compact.sort
  end

  def editori_options
    account.adozioni.distinct.pluck(:editore).compact.sort
  end

  private

  def apply_filtri(scope, filtri)
    scope = scope.where(disciplina: filtri[:disciplina]) if filtri[:disciplina].present?
    scope = scope.joins(:classe).where(classi: { anno_corso: filtri[:anno_corso] }) if filtri[:anno_corso].present?
    scope = scope.where(editore: filtri[:editore]) if filtri[:editore].present?
    if filtri[:gruppo].present?
      editore_names = Editore.where(gruppo: filtri[:gruppo]).pluck(:editore)
      scope = scope.where(editore: editore_names)
    end
    scope = scope.joins(classe: :scuola).where(scuole: { provincia: filtri[:provincia] }) if filtri[:provincia].present?
    scope = scope.joins(classe: :scuola).where(scuole: { grado: filtri[:grado] }) if filtri[:grado].present?
    scope = scope.joins(classe: :scuola).where(scuole: { tipo_scuola: filtri[:tipo_scuola] }) if filtri[:tipo_scuola].present?
    scope = scope.joins(classe: :scuola).where(scuole: { area: filtri[:area] }) if filtri[:area].present?
    scope
  end

  def apply_filtri_import(scope, filtri)
    scope = scope.where(DISCIPLINA: filtri[:disciplina]) if filtri[:disciplina].present?
    scope = scope.where(ANNOCORSO: filtri[:anno_corso]) if filtri[:anno_corso].present?
    scope = scope.where(EDITORE: filtri[:editore]) if filtri[:editore].present?
    scope
  end
end
