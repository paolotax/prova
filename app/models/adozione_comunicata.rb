# == Schema Information
#
# Table name: adozioni_comunicate
#
#  id                  :integer          not null, primary key
#  cod_agente          :string
#  anno_scolastico     :string
#  cod_ministeriale    :string
#  descrizione_scuola  :string
#  indirizzo           :string
#  cap                 :string
#  comune              :string
#  provincia           :string
#  cod_scuola          :string
#  editore             :string
#  ean                 :string
#  titolo              :string
#  classe              :string
#  sezione             :string
#  alunni              :integer
#  codice_scuola_match :string
#  codice_isbn_match   :string
#  anno_corso_match    :string
#  sezione_anno_match  :string
#  user_id             :integer          not null
#  import_adozione_id  :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  da_acquistare       :string
#
# Indexes
#
#  index_adozioni_comunicate_on_cod_ministeriale              (cod_ministeriale)
#  index_adozioni_comunicate_on_ean                           (ean)
#  index_adozioni_comunicate_on_import_adozione_id            (import_adozione_id)
#  index_adozioni_comunicate_on_user_id                       (user_id)
#  index_adozioni_comunicate_on_user_id_and_cod_ministeriale  (user_id,cod_ministeriale)
#  index_adozioni_comunicate_on_user_id_and_ean               (user_id,ean)
#

class AdozioneComunicata < ApplicationRecord
  belongs_to :user
  belongs_to :import_adozione, optional: true
  
  # Validazioni
  validates :ean, presence: true
  validates :cod_ministeriale, presence: true
  validates :titolo, presence: true
  validates :alunni, presence: true, numericality: { greater_than: 0 }
  
  # Scope per le adozioni dell'utente corrente
  scope :mie_adozioni_comunicate, -> { where(user: Current.user) }
  
  # Scope per confronto con import_adozioni
  scope :con_corrispondenza, -> { where.not(import_adozione_id: nil) }
  scope :senza_corrispondenza, -> { where(import_adozione_id: nil) }
  
  scope :da_acquistare, -> { where(da_acquistare: 'Si') }
  scope :da_non_acquistare, -> { where(da_acquistare: 'No') }

  # Scope per editore
  scope :per_editore, ->(editore) { where(editore: editore) }
  
  # Scope per scuola
  scope :per_scuola, ->(cod_ministeriale) { where(cod_ministeriale: cod_ministeriale) }
  
  # Scope per classe
  scope :per_classe, ->(classe) { where(classe: classe) }
  
  # Metodi per il confronto
  def trova_corrispondenza_import_adozione
    # Cerca corrispondenza per ISBN/EAN
    corrispondenza = ImportAdozione.mie_adozioni
                                  .where(CODICEISBN: ean)
                                  .where(CODICESCUOLA: cod_ministeriale)
                                  .where(ANNOCORSO: classe)
                                  .where(SEZIONEANNO: sezione)
                                  .first
    
    if corrispondenza
      update!(
        import_adozione: corrispondenza,
        codice_scuola_match: corrispondenza.CODICESCUOLA,
        codice_isbn_match: corrispondenza.CODICEISBN,
        anno_corso_match: corrispondenza.ANNOCORSO,
        sezione_anno_match: corrispondenza.SEZIONEANNO
      )
    end
    
    corrispondenza
  end
  
  def corrispondenza_trovata?
    import_adozione_id.present?
  end
  
  def differenze_con_import_adozione
    return {} unless import_adozione
    
    differenze = {}
    
    # Confronta i campi principali
    differenze[:titolo] = {
      comunicato: titolo,
      importato: import_adozione.TITOLO,
      uguali: titolo == import_adozione.TITOLO
    }
    
    differenze[:editore] = {
      comunicato: editore,
      importato: import_adozione.EDITORE,
      uguali: editore == import_adozione.EDITORE
    }
    
    differenze[:scuola] = {
      comunicato: descrizione_scuola,
      importato: import_adozione.import_scuola&.DENOMINAZIONESCUOLA,
      uguali: descrizione_scuola == import_adozione.import_scuola&.DENOMINAZIONESCUOLA
    }
    
    differenze[:classe_sezione] = {
      comunicato: "#{classe}#{sezione}",
      importato: "#{import_adozione.ANNOCORSO}#{import_adozione.SEZIONEANNO}",
      uguali: "#{classe}#{sezione}" == "#{import_adozione.ANNOCORSO}#{import_adozione.SEZIONEANNO}"
    }
    
    differenze
  end
  
  # Metodi per statistiche
  def self.statistiche_per_editore(user = Current.user)
    where(user: user)
      .da_acquistare
      .group(:editore)
      .select(:editore)
      .select('COUNT(*) as totale_record')
      .select('SUM(alunni) as totale_alunni')
      .select('COUNT(import_adozione_id) as corrispondenze_trovate')
  end
  
  def self.statistiche_per_scuola(user = Current.user)
    where(user: user)
      .da_acquistare
      .group(:cod_ministeriale, :descrizione_scuola)
      .select(:cod_ministeriale, :descrizione_scuola)
      .select('COUNT(*) as totale_record')
      .select('SUM(alunni) as totale_alunni')
      .select('COUNT(import_adozione_id) as corrispondenze_trovate')
  end
  
  def self.statistiche_per_classe(user = Current.user)
    where(user: user)
      .da_acquistare
      .group(:classe)
      .select(:classe)
      .select('COUNT(*) as totale_record')
      .select('SUM(alunni) as totale_alunni')
      .select('COUNT(import_adozione_id) as corrispondenze_trovate')
  end
  
  # Metodo helper per dividere il campo classi+sezioni
  def self.split_classi_sezioni(value)
    return [nil, nil] if value.nil? || value.to_s.strip.empty?
    
    value_str = value.to_s.strip
    
    # Pattern più comuni: "1A", "2B", "3C" -> Classe: "1", Sezione: "A"
    if match = value_str.match(/^(\d+)([A-Za-z]+)$/)
      return [match[1], match[2]]
    end
    
    # Pattern: "Classe X Sezione Y" o varianti
    if match = value_str.match(/(?:classe\s*)?(\d+)(?:\s*sezione\s*|\s*sez\s*)?([A-Za-z]+)/i)
      return [match[1], match[2]]
    end
    
    # Pattern: numero e lettera separati da simboli (/ - _ spazio)
    if match = value_str.match(/^(\d+)[\s\-\/_]+([A-Za-z]+)$/i)
      return [match[1], match[2]]
    end
    
    # Se non riesce a fare il parsing, prova a estrarre solo numeri e lettere
    numbers = value_str.scan(/\d+/)
    letters = value_str.scan(/[A-Za-z]+/)
    
    if numbers.length > 0 && letters.length > 0
      return [numbers.first, letters.first]
    elsif numbers.length > 0
      return [numbers.first, nil]
    elsif letters.length > 0
      return [nil, letters.first]
    end
    
    # Se tutto fallisce, restituisce il valore originale come classe
    return [value_str, nil]
  end

  # Metodo per importare da Excel
  def self.importa_da_excel(file_path, user)
    require 'roo'

    xlsx = Roo::Spreadsheet.open(file_path)
    xlsx.default_sheet = xlsx.sheets.first

    header = xlsx.row(1)
    importati = 0
    errori = 0
    aggiornati = 0
    non_autorizzati = 0

    (2..xlsx.last_row).each do |row_num|
      begin
        row = xlsx.row(row_num)
        row_data = Hash[header.zip(row)]

        # Gestisce il caso in cui arriva un campo "classi+sezioni" invece di "Classe" e "Sezione" separate
        classe = row_data['Classe']
        sezione = row_data['Sezione']

        # Se non ci sono i campi separati, cerca un campo combinato
        if (classe.nil? || classe.to_s.strip.empty?) && (sezione.nil? || sezione.to_s.strip.empty?)
          # Cerca varianti del nome del campo combinato
          classi_sezioni_value = row_data['classi+sezioni'] ||
                                 row_data['Classi+Sezioni'] ||
                                 row_data['Classi e Sezioni'] ||
                                 row_data['Classe+Sezione']

          if classi_sezioni_value
            classe, sezione = split_classi_sezioni(classi_sezioni_value)
          end
        end

        # FASE 1: RICERCA CORRISPONDENZA PRIMA DI TUTTO
        import_adozione_corrispondente = ImportAdozione.where(CODICEISBN: row_data['Ean'])
                                                       .where(CODICESCUOLA: row_data['CodMinisteriale'])
                                                       .where(ANNOCORSO: classe)
                                                       .where(SEZIONEANNO: sezione)
                                                       .first

        # FASE 2: COMPILAZIONE CAMPI VUOTI DAL DATABASE DESTINAZIONE
        # Gestisce la descrizione scuola: priorità a Excel, poi ImportScuola, poi ImportAdozione
        descrizione_scuola = row_data['Descrizione']
        if descrizione_scuola.nil? || descrizione_scuola.to_s.strip.empty?
          scuola_corrispondente = ImportScuola.find_by(CODICESCUOLA: row_data['CodMinisteriale'])
          if scuola_corrispondente
            descrizione_scuola = scuola_corrispondente.DENOMINAZIONESCUOLA
          elsif import_adozione_corrispondente&.import_scuola&.DENOMINAZIONESCUOLA
            descrizione_scuola = import_adozione_corrispondente.import_scuola.DENOMINAZIONESCUOLA
          end
        end

        # Gestisce l'editore: priorità a ImportAdozione
        if import_adozione_corrispondente
          editore = import_adozione_corrispondente.EDITORE
        else
          editore = row_data['Editore']
        end

        # CONTROLLO MANDATO: verifica che l'editore sia tra quelli dell'utente
        if editore.present? && !user.miei_editori.include?(editore)
          Rails.logger.warn "Editore '#{editore}' non autorizzato per utente #{user.name}. Record saltato."
          non_autorizzati += 1
          next  # Salta questo record se l'editore non è tra quelli autorizzati
        end

        # Gestisce da_acquistare: priorità a Excel, poi ImportAdozione
        da_acquistare = row_data['da_acquistare'] || row_data['DAACQUIST']
        if da_acquistare.nil? || da_acquistare.to_s.strip.empty?
          da_acquistare = import_adozione_corrispondente&.DAACQUIST
        end

        # Gestisce il titolo: priorità a Excel, poi ImportAdozione
        titolo = row_data['Titolo']
        if titolo.nil? || titolo.to_s.strip.empty?
          titolo = import_adozione_corrispondente&.TITOLO
        end

        # FASE 3: INSERIMENTO (anche senza corrispondenza)
        # Cerca se esiste già un record con le stesse caratteristiche
        adozione_esistente = find_by(
          user: user,
          cod_ministeriale: row_data['CodMinisteriale'],
          ean: row_data['Ean'],
          classe: classe,
          sezione: sezione
        )

        if adozione_esistente
          # Aggiorna il record esistente
          adozione_esistente.update!(
            cod_agente: row_data['Cod. Agente'],
            anno_scolastico: row_data['Anno'],
            descrizione_scuola: descrizione_scuola.present? ? descrizione_scuola : adozione_esistente.descrizione_scuola,
            indirizzo: row_data['Indirizzo'],
            cap: row_data['CAP'],
            comune: row_data['Comune'],
            provincia: row_data['Provincia'],
            cod_scuola: row_data['Cod. Sc.'],
            editore: editore.present? ? editore : adozione_esistente.editore,
            titolo: titolo.present? ? titolo : adozione_esistente.titolo,
            alunni: row_data['Alunni'].to_i,
            da_acquistare: da_acquistare.present? ? da_acquistare : adozione_esistente.da_acquistare,
            import_adozione: import_adozione_corrispondente,
            codice_scuola_match: import_adozione_corrispondente&.CODICESCUOLA,
            codice_isbn_match: import_adozione_corrispondente&.CODICEISBN,
            anno_corso_match: import_adozione_corrispondente&.ANNOCORSO,
            sezione_anno_match: import_adozione_corrispondente&.SEZIONEANNO
          )
          adozione = adozione_esistente
          aggiornati += 1
        else
          # Crea un nuovo record (anche senza corrispondenza)
          adozione = create!(
            user: user,
            cod_agente: row_data['Cod. Agente'],
            anno_scolastico: row_data['Anno'],
            cod_ministeriale: row_data['CodMinisteriale'],
            descrizione_scuola: descrizione_scuola,
            indirizzo: row_data['Indirizzo'],
            cap: row_data['CAP'],
            comune: row_data['Comune'],
            provincia: row_data['Provincia'],
            cod_scuola: row_data['Cod. Sc.'],
            editore: editore,
            ean: row_data['Ean'],
            titolo: titolo,
            classe: classe,
            sezione: sezione,
            alunni: row_data['Alunni'].to_i,
            da_acquistare: da_acquistare,
            import_adozione: import_adozione_corrispondente,
            codice_scuola_match: import_adozione_corrispondente&.CODICESCUOLA,
            codice_isbn_match: import_adozione_corrispondente&.CODICEISBN,
            anno_corso_match: import_adozione_corrispondente&.ANNOCORSO,
            sezione_anno_match: import_adozione_corrispondente&.SEZIONEANNO
          )
          importati += 1
        end

      rescue => e
        errori += 1
        Rails.logger.error "Errore importazione riga #{row_num}: #{e.message}"
      end
    end

    { importati: importati, aggiornati: aggiornati, errori: errori, non_autorizzati: non_autorizzati }
  end
  
  # Metodo per aggiornare tutte le corrispondenze
  def self.aggiorna_corrispondenze(user = Current.user)
    where(user: user, import_adozione_id: nil).find_each do |adozione|
      adozione.trova_corrispondenza_import_adozione
    end
  end
end
