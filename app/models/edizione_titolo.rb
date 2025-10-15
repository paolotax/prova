# == Schema Information
#
# Table name: edizioni_titoli
#
#  id               :bigint           not null, primary key
#  autore           :string
#  codice_isbn      :string
#  titolo_originale :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_edizioni_titoli_on_codice_isbn  (codice_isbn) UNIQUE
#
class EdizioneTitolo < ApplicationRecord
  has_many :libri, primary_key: :codice_isbn, foreign_key: :codice_isbn

  has_one_attached :copertina

  validates :codice_isbn, presence: true, uniqueness: true

  def avatar_url
    if copertina.attached?
      copertina
    else
      iniziali = (titolo_originale || "XX").split.map(&:first).join[0..1].upcase
      "https://ui-avatars.com/api/?name=#{iniziali}&color=7F9CF5&background=EBF4FF"
    end
  end
end
