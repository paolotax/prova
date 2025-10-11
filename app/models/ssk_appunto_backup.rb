# == Schema Information
#
# Table name: ssk_appunti_backup
#
#  id                                            :bigint           not null, primary key
#  active                                        :boolean
#  anno_corso                                    :string
#  anno_scolastico_backup                        :string
#  area_geografica                               :string
#  autori                                        :string
#  backup_created_at                             :datetime
#  body                                          :text
#  codice_isbn                                   :string
#  codice_istituto_riferimento                   :string
#  codice_scuola                                 :string
#  combinazione                                  :string
#  completed_at                                  :datetime
#  consigliato                                   :string
#  da_acquistare                                 :string
#  denominazione_istituto_riferimento            :string
#  denominazione_scuola                          :string
#  descrizione_caratteristica_scuola             :string
#  descrizione_comune                            :string
#  descrizione_tipologia_grado_istruzione_scuola :string
#  disciplina                                    :string
#  editore                                       :string
#  email                                         :string
#  libro_categoria                               :string
#  libro_disciplina                              :string
#  libro_note                                    :text
#  libro_prezzo_cents                            :integer
#  libro_titolo                                  :string
#  nome                                          :string
#  nuova_adozione                                :string
#  original_created_at                           :datetime
#  original_updated_at                           :datetime
#  prezzo                                        :string
#  provincia                                     :string
#  regione                                       :string
#  sezione_anno                                  :string
#  sottotitolo                                   :string
#  stato                                         :string
#  team                                          :string
#  telefono                                      :string
#  tipo_grado_scuola                             :string
#  titolo                                        :string
#  volume                                        :string
#  created_at                                    :datetime         not null
#  updated_at                                    :datetime         not null
#  classe_id                                     :bigint
#  import_adozione_id                            :bigint
#  import_scuola_id                              :bigint
#  libro_id                                      :bigint
#  original_appunto_id                           :bigint           not null
#  user_id                                       :bigint           not null
#
# Indexes
#
#  idx_on_codice_scuola_anno_corso_sezione_anno_19e7303a3f         (codice_scuola,anno_corso,sezione_anno)
#  index_ssk_appunti_backup_on_anno_scolastico_backup              (anno_scolastico_backup)
#  index_ssk_appunti_backup_on_codice_isbn                         (codice_isbn)
#  index_ssk_appunti_backup_on_codice_scuola                       (codice_scuola)
#  index_ssk_appunti_backup_on_nome                                (nome)
#  index_ssk_appunti_backup_on_original_appunto_id                 (original_appunto_id)
#  index_ssk_appunti_backup_on_user_id                             (user_id)
#  index_ssk_appunti_backup_on_user_id_and_anno_scolastico_backup  (user_id,anno_scolastico_backup)
#

class SskAppuntoBackup < ApplicationRecord
  belongs_to :user
  
  scope :per_utente, ->(user) { where(user_id: user.id) }
  scope :per_anno_scolastico, ->(anno) { where(anno_scolastico_backup: anno) }
  scope :saggi, -> { where(nome: 'saggio') }
  scope :seguiti, -> { where(nome: 'seguito') }
  scope :kit, -> { where(nome: 'kit') }
  
  def self.backup_ssk_appunti!(anno_scolastico = "202425")
    # Backup di TUTTI gli appunti che hanno un import_adozione_id o classe_id
    appunti_da_backuppare = Appunto.where("import_adozione_id IS NOT NULL OR classe_id IS NOT NULL")
                                   .includes(
                                     :user,
                                     :import_scuola,
                                     :import_adozione,
                                     :classe,
                                     import_adozione: [:import_scuola, :classe]
                                   )
    
    # Conta per tipologia per il log
    ssk_count = appunti_da_backuppare.where(nome: ['saggio', 'seguito', 'kit']).count
    con_adozioni_count = appunti_da_backuppare.where.not(import_adozione_id: nil).where.not(nome: ['saggio', 'seguito', 'kit']).count
    con_classi_count = appunti_da_backuppare.where.not(classe_id: nil).where(import_adozione_id: nil).count
    totale_count = appunti_da_backuppare.count
    
    Rails.logger.info "Trovati #{ssk_count} appunti SSK da salvare nel backup"
    Rails.logger.info "Trovati #{con_adozioni_count} altri appunti con adozioni da salvare nel backup"
    Rails.logger.info "Trovati #{con_classi_count} appunti con classi da salvare nel backup"
    Rails.logger.info "Totale: #{totale_count} appunti da salvare nel backup"
    
    backup_count = 0
    
    # Backup di tutti gli appunti con import_adozione_id o classe_id
    appunti_da_backuppare.find_each(batch_size: 100) do |appunto|
      backup_data = build_backup_data(appunto, anno_scolastico)
      
      # Evita duplicati - controlla se esiste già un backup per questo appunto
      unless exists?(original_appunto_id: appunto.id, anno_scolastico_backup: anno_scolastico)
        create!(backup_data)
        backup_count += 1
      end
    end
    
    Rails.logger.info "Salvati #{backup_count} appunti nel backup (#{backup_count}/#{totale_count})"
    backup_count
  end
  
  def self.build_backup_data(appunto, anno_scolastico)
    import_scuola = appunto.import_scuola
    import_adozione = appunto.import_adozione
    classe = appunto.classe
    libro = import_adozione&.libro
    
    {
      # Dati originali appunto
      original_appunto_id: appunto.id,
      user_id: appunto.user_id,
      nome: appunto.nome,
      body: appunto.body,
      email: appunto.email,
      telefono: appunto.telefono,
      stato: appunto.stato,
      team: appunto.team,
      active: appunto.active,
      completed_at: appunto.completed_at,
      original_created_at: appunto.created_at,
      original_updated_at: appunto.updated_at,
      
      # Dati scuola
      import_scuola_id: import_scuola&.id,
      codice_scuola: import_scuola&.CODICESCUOLA,
      denominazione_scuola: import_scuola&.DENOMINAZIONESCUOLA,
      descrizione_comune: import_scuola&.DESCRIZIONECOMUNE,
      descrizione_caratteristica_scuola: import_scuola&.DESCRIZIONECARATTERISTICASCUOLA,
      descrizione_tipologia_grado_istruzione_scuola: import_scuola&.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA,
      codice_istituto_riferimento: import_scuola&.CODICEISTITUTORIFERIMENTO,
      denominazione_istituto_riferimento: import_scuola&.DENOMINAZIONEISTITUTORIFERIMENTO,
      area_geografica: import_scuola&.AREAGEOGRAFICA,
      regione: import_scuola&.REGIONE,
      provincia: import_scuola&.PROVINCIA,
      
      # Dati adozione
      import_adozione_id: import_adozione&.id,
      codice_isbn: import_adozione&.CODICEISBN,
      autori: import_adozione&.AUTORI,
      titolo: import_adozione&.TITOLO,
      sottotitolo: import_adozione&.SOTTOTITOLO,
      volume: import_adozione&.VOLUME,
      editore: import_adozione&.EDITORE,
      prezzo: import_adozione&.PREZZO,
      disciplina: import_adozione&.DISCIPLINA,
      nuova_adozione: import_adozione&.NUOVAADOZ,
      da_acquistare: import_adozione&.DAACQUIST,
      consigliato: import_adozione&.CONSIGLIATO,
      
      # Dati classe
      classe_id: classe&.id,
      anno_corso: import_adozione&.ANNOCORSO,
      sezione_anno: import_adozione&.SEZIONEANNO,
      combinazione: import_adozione&.COMBINAZIONE,
      tipo_grado_scuola: import_adozione&.TIPOGRADOSCUOLA,
      
      # Dati libro utente
      libro_id: libro&.id,
      libro_titolo: libro&.titolo,
      libro_categoria: libro&.categoria,
      libro_disciplina: libro&.disciplina,
      libro_prezzo_cents: libro&.prezzo_in_cents,
      libro_note: libro&.note,
      
      # Anno scolastico backup
      anno_scolastico_backup: anno_scolastico
    }
  end
  
  def classe_e_sezione
    "#{anno_corso} #{sezione_anno&.titleize}"
  end
  
  def scuola_e_citta
    "#{denominazione_scuola} - #{descrizione_comune}"
  end
  
  def titolo_e_editore
    "#{titolo} - #{editore}"
  end
end
