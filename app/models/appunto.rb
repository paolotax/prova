class Appunto < ApplicationRecord
  belongs_to :import_scuola
  belongs_to :user
  belongs_to :import_adozione, required: false

  has_one_attached :image
  has_many_attached :attachments
  has_rich_text :content

  def image_as_thumbnail
    return unless image.content_type.in?(%w[image/jpeg image/png])
    self.image.variant(resize_to_limit: [300, 300]).processed
  end

  def appunto_attachment(index)
    target = attachments[index]
    return unless attachments.attached?

    if target.image?
      target.variant(resize_to_limit: [150, 150]).processed
    elsif target.video?
      target.variant(resize_to_limit: [150, 150]).processed
    end
  end

end
