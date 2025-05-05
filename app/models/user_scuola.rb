# == Schema Information
#
# Table name: user_scuole
#
#  id               :integer          not null, primary key
#  import_scuola_id :integer          not null
#  user_id          :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  position         :integer
#
# Indexes
#
#  index_user_scuole_on_import_scuola_id      (import_scuola_id)
#  index_user_scuole_on_user_id               (user_id)
#  index_user_scuole_on_user_id_and_position  (user_id,position)
#

class UserScuola < ApplicationRecord
  belongs_to :import_scuola
  belongs_to :user

  positioned on: :user

  def self.generate_positions_by_provincia_comune_direzione
    self.joins(:import_scuola).group_by(&:user_id).each do |user_id, user_scuole|
      index = 1  # Iniziamo da 1 invece di 0
      sorted_scuole = user_scuole.sort_by do |user_scuola| 
        [
          user_scuola.import_scuola.PROVINCIA.to_s,  # Convertiamo in string
          user_scuola.import_scuola.direzione.nil? ? user_scuola.import_scuola.DESCRIZIONECOMUNE.to_s : user_scuola.import_scuola.direzione.DESCRIZIONECOMUNE.to_s,
          user_scuola.import_scuola.CODICEISTITUTORIFERIMENTO.to_s
        ]
      end
      
      sorted_scuole.each do |user_scuola|
        user_scuola.update(position: index)
        index += 1
      end
    end
  end

end
