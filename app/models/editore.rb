class Editore < ApplicationRecord
    validates :editore, uniqueness: true

    has_many :users, through: :editori_users

    has_many :import_adozioni, foreign_key: "EDITORE", primary_key: "editore"
    has_many :import_scuole, through: :import_adozioni

    def self.di_zona(user) 
        
        #Editore.joins(:import_adozioni).where("import_adozioni.REGIONE = ?", self.import_adozioni.first.REGIONE).distinct

    end
end
