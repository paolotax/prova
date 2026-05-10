# == Schema Information
#
# Table name: documento_righe
#
#  id           :bigint           not null, primary key
#  posizione    :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  documento_id :uuid
#  riga_id      :bigint
#
# Indexes
#
#  index_documento_righe_on_documento_id              (documento_id)
#  index_documento_righe_on_documento_id_and_riga_id  (documento_id,riga_id) UNIQUE
#  index_documento_righe_on_riga_id                   (riga_id)
#

class DocumentoRiga < ApplicationRecord

  acts_as_list scope: :documento, column: "posizione"

  belongs_to :documento
  belongs_to :riga
  has_one :bolla_visione_riga

  accepts_nested_attributes_for :riga #, :reject_if => lambda { |a| (a[:quantita].blank? || a[:libro_id].blank?)}, :allow_destroy => false

  after_save :aggiorna_totali_documento
  after_destroy :aggiorna_totali_documento
  after_destroy_commit :rientra_bolla_visione_riga

  private

  def aggiorna_totali_documento
    return unless documento
    documento.righe.reset unless documento.previously_new_record?
    documento.ricalcola_totali!
  end

  def rientra_bolla_visione_riga
    bolla_visione_riga&.update_columns(
      esito: BollaVisioneRiga.esiti[:rientrato],
      documento_riga_id: nil
    )
  end
end
