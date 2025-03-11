# == Schema Information
#
# Table name: qrcodes
#
#  id             :bigint           not null, primary key
#  description    :text
#  qrcodable_type :string
#  url            :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  qrcodable_id   :bigint
#
# Indexes
#
#  index_qrcodes_on_qrcodable  (qrcodable_type,qrcodable_id)
#
class Qrcode < ApplicationRecord
  belongs_to :qrcodable, polymorphic: true, optional: true
  
  has_one_attached :image
  
  #validates :url, presence: true
  
  after_create :generate_qrcode
  after_update :generate_qrcode, if: :url_changed?
  
  private
  
  def generate_qrcode
    require 'rqrcode'
    
    qrcode = RQRCode::QRCode.new(url)
    png = qrcode.as_png(
      bit_depth: 1,
      border_modules: 4,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: 'black',
      file: nil,
      fill: 'white',
      module_px_size: 6,
      resize_exactly_to: false,
      resize_gte_to: false,
      size: 300
    )
    
    io = StringIO.new(png.to_s)
    filename = "qrcode_#{Time.now.to_i}.png"
    
    # Rimuovi l'immagine esistente se presente
    image.purge if image.attached?
    
    # Allega la nuova immagine
    image.attach(io: io, filename: filename, content_type: 'image/png')
  end
end 
