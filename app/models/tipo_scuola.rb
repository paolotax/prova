# == Schema Information
#
# Table name: tipi_scuole
#
#  id         :bigint           not null, primary key
#  tipo       :string
#  grado      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class TipoScuola < ApplicationRecord
end
