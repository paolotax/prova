# == Schema Information
#
# Table name: zone
#
#  id              :bigint           not null, primary key
#  area_geografica :string
#  regione         :string
#  provincia       :string
#  comune          :string
#  codice_comune   :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Zona < ApplicationRecord
end
