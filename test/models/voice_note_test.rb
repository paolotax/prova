# == Schema Information
#
# Table name: voice_notes
#
#  id            :integer          not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :integer          not null
#  title         :text
#  transcription :text
#
# Indexes
#
#  index_voice_notes_on_user_id  (user_id)
#

require "test_helper"

class VoiceNoteTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
