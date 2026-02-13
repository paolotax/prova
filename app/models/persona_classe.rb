# == Schema Information
#
# Table name: persona_classi
#
#  id         :uuid             not null, primary key
#  materia    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  classe_id  :uuid             not null
#  persona_id :uuid             not null
#
# Indexes
#
#  index_persona_classi_on_classe_id                 (classe_id)
#  index_persona_classi_on_persona_id                (persona_id)
#  index_persona_classi_on_persona_id_and_classe_id  (persona_id,classe_id) UNIQUE
#
class PersonaClasse < ApplicationRecord
  belongs_to :persona
  belongs_to :classe
end
