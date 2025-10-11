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
  has_many :appunti, dependent: :nullify

  validates :audio_file, presence: true
  validates :user, presence: true

  before_validation :set_title
  def set_title
    self.title = "Nota vocale del #{Time.now.strftime("%d-%m ore %H:%M")}" if title.blank?
  end

  # after_create_commit :schedule_transcription, if: :audio_file_attached?
  # after_update_commit -> { 
  #   broadcast_replace_to "voice_notes",
  #                       target: "voice_note_#{id}",
  #                       partial: "voice_notes/voice_note",
  #                       locals: { voice_note: self }
  # }

  # def schedule_transcription
  #   TranscribeVoiceNoteJob.perform_async(id)
  # end

  def audio_file_attached?
    audio_file.attached?
  end

  def transcribed?
    transcription.present?
  end

  
end
