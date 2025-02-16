# == Schema Information
#
# Table name: giri
#
#  id           :bigint           not null, primary key
#  conditions   :text
#  descrizione  :string
#  excluded_ids :text
#  finito_il    :datetime
#  iniziato_il  :datetime
#  stato        :string
#  titolo       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_giri_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Giro < ApplicationRecord
  
  belongs_to :user
  
  has_many :tappe, dependent: :nullify

  validates :titolo, presence: true
  
  broadcasts_to ->(giro) { [giro.user, "giri"] }

  serialize :conditions, coder: YAML
  serialize :excluded_ids, coder: YAML

  before_save :normalize_arrays

  def to_combobox_display
    titolo
  end

  def can_delete?
    tappe.empty?
  end

  def next
    self.class.where("id > ? and user_id = ?", id, user_id).first
  end

  def previous
    self.class.where("id < ? and user_id = ?", id, user_id).last
  end

  def giro_ritiri?
    titolo == "Ritiri"
  end

  def filter_schools(schools)
    schools = schools.to_a
    
    # Escludi le scuole specificate
    schools = schools.reject { |s| excluded_ids.include?(s.id.to_s) } if excluded_ids.present?
    
    # Applica le condizioni
    # if conditions.present?
    #   conditions.each do |condition|
    #     case condition
    #     when 'with_adozioni'
    #       schools = schools.select { |s| s.adozioni.any? }
    #     when 'with_appunti'
    #       schools = schools.select { |s| s.appunti.any? }
    #     when 'with_ordini'
    #       schools = schools.select { |s| s.ordini.any? }
    #     end
    #   end
    # end
    
    schools
  end

  private

  def normalize_arrays
    self.conditions = [] if conditions.nil?
    self.excluded_ids = [] if excluded_ids.nil?
    
    # Assicurati che gli ID siano stringhe
    self.excluded_ids = excluded_ids.map(&:to_s) if excluded_ids.present?
  end

end
