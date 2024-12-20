# == Schema Information
#
# Table name: voice_notes
#
#  id            :bigint           not null, primary key
#  title         :text
#  transcription :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_voice_notes_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class VoiceNote < ApplicationRecord

  belongs_to :user
   
  has_one_attached :audio_file

  validates :audio_file, presence: true
  validates :user, presence: true

  before_validation :set_title
  def set_title
    self.title = "Nota vocale del #{Time.zone.now.strftime("%d-%m..%H:%M")}" if title.blank?
  end

end
