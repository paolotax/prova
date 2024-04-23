class Adozione < ApplicationRecord
  belongs_to :user
  belongs_to :import_adozione
  belongs_to :libro


  def self.stato_adozione
    order(:stato_adozione).distinct.pluck(:stato_adozione).compact
  end

end
