# == Schema Information
#
# Table name: libri
#
#  id              :bigint           not null, primary key
#  categoria       :string
#  classe          :integer
#  codice_isbn     :string
#  disciplina      :string
#  note            :text
#  prezzo_in_cents :integer
#  titolo          :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  editore_id      :bigint
#  user_id         :bigint           not null
#
# Indexes
#
#  index_libri_on_classe_and_disciplina    (classe,disciplina)
#  index_libri_on_editore_id               (editore_id)
#  index_libri_on_user_id                  (user_id)
#  index_libri_on_user_id_and_categoria    (user_id,categoria)
#  index_libri_on_user_id_and_codice_isbn  (user_id,codice_isbn)
#  index_libri_on_user_id_and_editore_id   (user_id,editore_id)
#  index_libri_on_user_id_and_titolo       (user_id,titolo)
#
# Foreign Keys
#
#  fk_rails_...  (editore_id => editori.id)
#  fk_rails_...  (user_id => users.id)
#
class Libro < ApplicationRecord

  include Searchable
  search_on :titolo, :codice_isbn, :disciplina, :note, :categoria, editore: :editore

  extend FilterableModel
  class << self
    def filter_proxy = Filters::LibroFilterProxy
  end


  monetize :prezzo_in_cents

  belongs_to :user
  belongs_to :editore, optional: true
  
  has_many :adozioni
  has_many :righe
  has_many :documenti, through: :righe
  has_many :documento_righe, through: :righe

  validates :titolo, presence: true
  validates :editore, presence: true
  validates :prezzo_in_cents, presence: true, numericality: { greater_than: 0 }
  validates :codice_isbn, presence: true, uniqueness: true

  def self.categorie
    order(:categoria).distinct.pluck(:categoria).compact
  end

  def to_combobox_display
    self.titolo
  end

  # ora così poi devo vedere come funziona money-rails
  def prezzo
    prezzo_in_cents.to_f / 100
  end

  def prezzo=(valore)
    self.prezzo_in_cents = (valore.to_f * 100).to_i
  end


  def self.crosstab
    
    # Costruisci la lista delle causali
    causali = Causale.order(:id).all.map(&:causale)

    # Costruisci la query dinamica
    crosstab_query = <<-SQL
      WITH situazio AS (
        SELECT *
        FROM crosstab(
          $$
          SELECT libri.id, causali.causale, sum(righe.quantita) as quantita
          FROM libri
                  JOIN righe ON righe.libro_id = libri.id
                  JOIN documento_righe on righe.id = documento_righe.riga_id
                  JOIN documenti on documento_righe.documento_id = documenti.id
                  JOIN causali on documenti.causale_id = causali.id
                  JOIN users on documenti.user_id = users.id 
          WHERE users.id = #{Current.user.id}
          GROUP BY libri.id, causali.causale
          ORDER BY libri.id
          $$, $$
          SELECT causali.causale
          FROM causali ORDER BY causali.id
          $$
        ) AS ct (id bigint, #{causali.map { |c| "#{c.gsub(' ', '_')} bigint" }.join(', ')})
      ) 
      SELECT libri.titolo, libri.categoria, libri.codice_isbn, editori.editore, libri.prezzo_in_cents, situazio.*
      FROM libri
      INNER JOIN situazio ON libri.id = situazio.id
      INNER JOIN editori ON editori.id =  libri.editore_id
    SQL

    puts crosstab_query

    # Esegui la query
    result = ActiveRecord::Base.connection.execute(crosstab_query)
    # Stampa i risultati
    result.each do |row|
      puts row
    end
    result
  end

end
