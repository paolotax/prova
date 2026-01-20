# frozen_string_literal: true

# == Schema Information
#
# Table name: columns
#
#  id         :uuid             not null, primary key
#  color      :string           default("#6366f1")
#  name       :string           not null
#  position   :integer          default(0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :uuid             not null
#
# Indexes
#
#  index_columns_on_account_id               (account_id)
#  index_columns_on_account_id_and_name      (account_id,name) UNIQUE
#  index_columns_on_account_id_and_position  (account_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

class Column < ApplicationRecord
  include AccountScoped

  has_many :entries, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :account_id }

  positioned on: :account, column: :position

  scope :ordered, -> { order(:position) }

  # Default columns for new accounts
  DEFAULT_COLUMNS = [
    { name: "Consegna Collana", color: "#22c55e" },
    { name: "Ritiro Collana", color: "#f97316" },
    { name: "Consegna Vacanze", color: "#3b82f6" },
    { name: "Ritiro Vacanze", color: "#8b5cf6" }
  ].freeze

  def self.create_defaults_for(account)
    DEFAULT_COLUMNS.each_with_index do |attrs, index|
      account.columns.find_or_create_by!(name: attrs[:name]) do |col|
        col.color = attrs[:color]
        col.position = index
      end
    end
  end

  def entries_count
    entries.count
  end
end
