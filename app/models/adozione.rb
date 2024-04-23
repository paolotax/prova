class Adozione < ApplicationRecord
  belongs_to :user
  belongs_to :import_adozione
  
  belongs_to :libro, optional: true


  def self.stato_adozione
    order(:stato_adozione).distinct.pluck(:stato_adozione).compact
  end

  def new_libro=(new_libro)
    libro = Current.user.libri.find_or_create_by(titolo: new_libro)
    libro.prezzo_in_cents = 0
    libro.save
    self.libro = libro
  end

  def maestre
    team.split(",").map{ |m| m.strip.split(" e ") }.flatten
  end

  
end
