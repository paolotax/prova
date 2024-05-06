# == Schema Information
#
# Table name: profiles
#
#  id              :bigint           not null, primary key
#  cap             :string
#  cellulare       :string
#  citta           :string
#  cognome         :string
#  email           :string
#  iban            :string
#  indirizzo       :string
#  nome            :string
#  nome_banca      :string
#  ragione_sociale :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_profiles_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Profile < ApplicationRecord

  belongs_to :user
  
end
