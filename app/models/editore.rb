# == Schema Information
#
# Table name: editori
#
#  id         :integer          not null, primary key
#  editore    :string
#  gruppo     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Editore < ApplicationRecord

    include Searchable

    search_on :editore, :gruppo

    validates :editore, presence: true
    validates :editore, uniqueness: true

    has_many :mandati, dependent: :destroy
    has_many :users, through: :mandati

    has_many :import_adozioni, foreign_key: "EDITORE", primary_key: "editore"
    has_many :import_scuole, through: :import_adozioni

    scope :miei_editori, ->(user) { joins(:mandati).where("mandati.user_id = ?", user.id) }

    def self.ransackable_attributes(_auth_object = nil)
        %w[editore gruppo]
    end

    def self.ransackable_associations(_auth_object = nil)
        %w[editore gruppo]
    end
    
    def self.di_zona(user) 
        
        #Editore.joins(:import_adozioni).where("import_adozioni.REGIONE = ?", self.import_adozioni.first.REGIONE).distinct

    end

    
end
