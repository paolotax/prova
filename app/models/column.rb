# frozen_string_literal: true

# == Schema Information
#
# Table name: columns
#
#  id         :uuid             not null, primary key
#  color      :string           default("var(--color-card-default)")
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
  include Colored

  has_many :entries, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :account_id }

  scope :ordered, -> { order(:position) }

  before_create :set_position_at_end

  # Default columns for new accounts
  DEFAULT_COLUMNS = [
    { name: "Nel baule", color: "var(--color-card-4)" },   # Lime
    { name: "La prossima", color: "var(--color-card-2)" }    # Purple
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

  def left_column
    account.columns.where("position < ?", position).ordered.last
  end

  def right_column
    account.columns.where("position > ?", position).ordered.first
  end

  def leftmost?
    left_column.nil?
  end

  def rightmost?
    right_column.nil?
  end

  def adjacent_columns
    account.columns.where(id: [ left_column&.id, right_column&.id ].compact)
  end

  def move_left
    swap_position_with(left_column)
  end

  def move_right
    swap_position_with(right_column)
  end

  private
    def set_position_at_end
      max_position = account.columns.maximum(:position) || -1
      self.position = max_position + 1
    end

    def swap_position_with(other_column)
      return if other_column.nil?

      transaction do
        old_position = position
        update_column(:position, other_column.position)
        other_column.update_column(:position, old_position)
      end
    end
end
