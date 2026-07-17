# == Schema Information
#
# Table name: adozioni_comunicate
#
#  id                 :uuid             not null, primary key
#  alunni             :integer          not null
#  anno_corso         :string           not null
#  anno_scolastico    :string           not null
#  codicescuola       :string           not null
#  comune             :string
#  descrizione_scuola :string
#  ean                :string           not null
#  editore            :string
#  fonte              :string           default("excel"), not null
#  provincia          :string
#  sezioni            :string           default(""), not null
#  stato_match        :string           default("da_verificare"), not null
#  titolo             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :uuid             not null
#  adozione_id        :uuid
#  classe_id          :uuid
#  import_record_id   :uuid
#
# Indexes
#
#  index_adozioni_comunicate_on_account_id_and_stato_match  (account_id,stato_match)
#  index_adozioni_comunicate_on_adozione_id                 (adozione_id)
#  index_adozioni_comunicate_unicita                        (account_id,anno_scolastico,codicescuola,ean,anno_corso,sezioni) UNIQUE
#
module Adozioni
  class Comunicata < ApplicationRecord
    self.table_name = "adozioni_comunicate"

    include AccountScoped

    STATI_MATCH = %w[
      da_verificare matched adozione_non_trovata classe_non_trovata
      multi_sezione multi_sezione_distribuita
    ].freeze

    belongs_to :adozione, optional: true
    belongs_to :classe, optional: true
    belongs_to :import_record, optional: true

    validates :anno_scolastico, :codicescuola, :ean, :anno_corso, presence: true
    validates :alunni, presence: true, numericality: { greater_than: 0 }
    validates :stato_match, inclusion: { in: STATI_MATCH }

    scope :per_anno, ->(anno) { where(anno_scolastico: anno) }
    scope :matched, -> { where(stato_match: %w[matched multi_sezione_distribuita]) }
    scope :discrepanze, -> { where(stato_match: %w[adozione_non_trovata classe_non_trovata multi_sezione]) }
    scope :per_editore, ->(editore) { where(editore: editore) }

    def self.normalizza_ean(raw)
      raw.to_s.gsub(/[^0-9Xx]/, "").upcase
    end

    def sezioni_lista
      sezioni.to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def multi_sezione?
      sezioni_lista.size > 1
    end
  end
end
