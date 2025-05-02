# == Schema Information
#
# Table name: profiles
#
#  id              :integer          not null, primary key
#  user_id         :integer          not null
#  nome            :string
#  cognome         :string
#  ragione_sociale :string
#  indirizzo       :string
#  cap             :string
#  citta           :string
#  cellulare       :string
#  email           :string
#  iban            :string
#  nome_banca      :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_profiles_on_user_id  (user_id)
#

class Profile < ApplicationRecord

  belongs_to :user

  attr_accessor :form_step

  with_options if: -> { required_for_step?(:informazioni_personali) } do
    validates :nome, presence: true
    validates :cognome, presence: true
    
  end

  with_options if: -> { required_for_step?(:address_info) } do
    validates :ragione_sociale, presence: true
    validates :indirizzo, presence: true
    validates :citta, presence: true
  end

  with_options if: -> { required_for_step?(:bank_info) } do
    validates :nome_banca, presence: true
    validates :iban, presence: true
  end

  def self.form_steps
    {
      informazioni_personali: [:nome, :cognome, :cellulare, :email],
      address_info: [:indirizzo, :citta, :ragione_sociale, :cap],
      bank_info: [:nome_banca, :iban]
    }
  end

  def required_for_step?(step)
    # All fields are required if no form step is present
    return true if form_step.nil?

    # All fields from previous steps are required
    ordered_keys = self.class.form_steps.keys.map(&:to_sym)
    !!(ordered_keys.index(step) <= ordered_keys.index(form_step))
  end
  
end
