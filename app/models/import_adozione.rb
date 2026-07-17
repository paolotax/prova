# == Schema Information
#
# Table name: import_adozioni
#
#  id              :bigint           primary key
#  ANNOCORSO       :string
#  AUTORI          :string
#  CODICEISBN      :string
#  CODICESCUOLA    :string
#  COMBINAZIONE    :string
#  CONSIGLIATO     :string
#  DAACQUIST       :string
#  DISCIPLINA      :string
#  EDITORE         :string
#  NUOVAADOZ       :string
#  PREZZO          :string
#  SEZIONEANNO     :string
#  SOTTOTITOLO     :string
#  TIPOGRADOSCUOLA :string
#  TITOLO          :string
#  VOLUME          :string
#  anno_scolastico :string
#

class ImportAdozione < ApplicationRecord
  # import_adozioni e' una vista ponte READ-ONLY sulla partizione 202526 di
  # miur_adozioni: le viste non dichiarano PK, quindi la esplicitiamo perche'
  # Adozione la risolve via belongs_to :import_adozione (per id).
  self.primary_key = "id"

  belongs_to :import_scuola, foreign_key: 'CODICESCUOLA', primary_key: 'CODICESCUOLA'
  belongs_to :editore,       foreign_key: 'EDITORE',      primary_key: 'EDITORE'

  has_one :classe, class_name: 'Views::Classe',
                   primary_key: %i[CODICESCUOLA ANNOCORSO SEZIONEANNO COMBINAZIONE],
                   foreign_key: %i[codice_ministeriale classe sezione combinazione]

  has_many :user_scuole, through: :import_scuola
  has_many :users, through: :user_scuole

  scope :per_scuola_classe_sezione_disciplina, -> { order(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :DISCIPLINA) }

  scope :per_scuola_classe_disciplina_sezione, -> { order(:CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :SEZIONEANNO) }

  scope :classi_che_adottano, -> { where(ANNOCORSO: [3, 5]) }

  scope :raggruppate, lambda {
    order(%i[ANNOCORSO DISCIPLINA TITOLO CODICEISBN EDITORE])
      .group(:ANNOCORSO, :DISCIPLINA, :TITOLO, :CODICEISBN, :EDITORE)
      .select(:ANNOCORSO, :DISCIPLINA, :TITOLO, :CODICEISBN, :EDITORE)
      .select('ARRAY_AGG(import_adozioni.id) AS import_adozioni_ids')
      .select('COUNT(import_adozioni.id) as numero_sezioni')
  }

  scope :grouped_titolo, lambda {
    order(:CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :CODICEISBN, :TITOLO, :EDITORE)
      .group(:CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :CODICEISBN, :TITOLO, :EDITORE)
      .select(:CODICESCUOLA, :ANNOCORSO, :DISCIPLINA, :CODICEISBN, :TITOLO, :EDITORE)
      .select('ARRAY_AGG(import_adozioni.id) AS import_adozioni_ids')
      .select('ARRAY_AGG(import_adozioni."SEZIONEANNO") AS import_adozioni_sezioni')
      .select('ARRAY_AGG(import_adozioni."COMBINAZIONE") AS import_adozioni_combinazione')
  }

  scope :grouped_classe, lambda {
    order(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE)
      .group(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE)
      .select(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE)
      .select('ARRAY_AGG(import_adozioni.id) AS import_adozioni_ids')
  }

  scope :da_acquistare, -> { where(DAACQUIST: 'Si') }
  scope :da_non_acquistare, -> { where(DAACQUIST: 'No') }
  scope :adozioni_144, -> {
    where(ANNOCORSO: Stats::Calcolo144::CLASSI_144, DISCIPLINA: Stats::Calcolo144.discipline_names)
  }
  scope :scorrimenti_235, -> {
    where(ANNOCORSO: Stats::Calcolo144::CLASSI_235)
  }

  delegate :codice_ministeriale, :scuola, :citta, :tipo_scuola, :tipo_nome, to: :import_scuola

  def to_s
    "#{classe_e_sezione} - #{titolo} - #{editore}"
  end

  def anno
    self.ANNOCORSO
  end

  def codice_scuola
    self.CODICESCUOLA
  end

  def classe_e_sezione
    "#{self.ANNOCORSO} #{sezione}"
  end

  def classe_e_combinazione
    "#{self.ANNOCORSO} #{sezione} #{self.COMBINAZIONE.downcase}"
  end

  def classe_e_sezione_e_disciplina
    "#{self.ANNOCORSO} #{sezione} #{self.DISCIPLINA.downcase}"
  end

  def sezione
    self.SEZIONEANNO.titleize
  end

  def disciplina
    self.DISCIPLINA.titleize
  end

  def combinazione
    self.COMBINAZIONE.downcase
  end

  def titolo
    ApplicationController.helpers.titleize_con_apostrofi self.TITOLO
  end

  def autori
    ApplicationController.helpers.titleize_con_apostrofi self.AUTORI
  end

  def editore
    self.EDITORE.upcase
  end

  def codice_isbn
    self.CODICEISBN
  end

  def prezzo
    self.PREZZO
  end

  def nuova_adozione
    self.NUOVAADOZ
  end

  def da_acquistare
    self.DAACQUIST
  end

  def da_acquistare?
    return false unless has_attribute?(:DAACQUIST)
    self.DAACQUIST == 'Si'
  end

  def consigliato
    self.CONSIGLIATO
  end
end
