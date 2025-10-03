# == Schema Information
#
# Table name: chats
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  model_id   :integer
#
# Indexes
#
#  index_chats_on_model_id  (model_id)
#  index_chats_on_user_id   (user_id)
#

class Chat < ApplicationRecord
  belongs_to :user
  acts_as_chat

  broadcasts_to ->(chat) { [chat, "messages"] }
end
