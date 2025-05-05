# == Schema Information
#
# Table name: documento_righe
#
#  id           :integer          not null, primary key
#  documento_id :integer
#  riga_id      :integer
#  posizione    :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
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

  accepts_nested_attributes_for :riga #, :reject_if => lambda { |a| (a[:quantita].blank? || a[:libro_id].blank?)}, :allow_destroy => false

end
