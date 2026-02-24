# == Schema Information
#
# Table name: zone
#
#  id              :bigint           not null, primary key
#  area_geografica :string
#  codice_comune   :string
#  comune          :string
#  provincia       :string
#  regione         :string
#  sigla           :string(2)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class Zona < ApplicationRecord
  def self.sigla_per(provincia)
    where(provincia: provincia).pick(:sigla)
  end
end
