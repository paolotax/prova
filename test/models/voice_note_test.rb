# == Schema Information
#
# Table name: voice_notes
#
#  id         :bigint           not null, primary key
#  title      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_voice_notes_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class VoiceNoteTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
