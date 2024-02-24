# == Schema Information
#
# Table name: appunti
#
#  id                 :bigint           not null, primary key
#  import_scuola_id   :bigint           not null
#  user_id            :bigint           not null
#  import_adozione_id :bigint
#  nome               :string
#  body               :text
#  email              :string
#  telefono           :string
#  stato              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class Appunto < ApplicationRecord
  belongs_to :import_scuola, required: false
  belongs_to :user
  belongs_to :import_adozione, required: false

  has_one_attached :image
  has_many_attached :attachments
  has_rich_text :content

  scope :search, ->(q) do 
     includes(:import_scuola)
     .where("nome ILIKE ? or import_scuole.DENOMINAZIONESCUOLA ILIKE ? or import_scuole.DESCRIZIONECOMUNE ILIKE ? ", 
     "%#{q}%", "%#{q}%", "%#{q}%") 
  end

  def image_as_thumbnail
    return unless image.content_type.in?(%w[image/jpeg image/png image/jpg image/gif image/webp])
    self.image.variant(resize_to_limit: [300, 300]).processed
  end

  def appunto_attachment(index)
    target = attachments[index]
    return unless attachments.attached?

    if target.image?
      target.variant(resize_to_limit: [200, 200]).processed
    elsif target.video?
      target.variant(resize_to_limit: [200, 200]).processed
    end
  end

end
