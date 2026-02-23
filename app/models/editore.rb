# == Schema Information
#
# Table name: editori
#
#  id         :bigint           not null, primary key
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

    has_many :mandati, class_name: "Accounts::Mandato", dependent: :destroy
    has_many :legacy_mandati, class_name: "LegacyMandato", dependent: :destroy
    has_many :users, through: :legacy_mandati

    # Relazione con sconti
    has_many :sconti, as: :scontabile, dependent: :destroy

    def self.ransackable_attributes(_auth_object = nil)
        %w[editore gruppo]
    end

    def self.ransackable_associations(_auth_object = nil)
        %w[editore gruppo]
    end
end
