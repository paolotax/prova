# frozen_string_literal: true

# == Schema Information
#
# Table name: events
#
#  id          :uuid             not null, primary key
#  action      :string           not null
#  particulars :jsonb
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :uuid             not null
#  entry_id    :uuid             not null
#  user_id     :bigint
#
# Indexes
#
#  index_events_on_account_id               (account_id)
#  index_events_on_account_id_and_action    (account_id,action)
#  index_events_on_entry_id                 (entry_id)
#  index_events_on_entry_id_and_created_at  (entry_id,created_at)
#  index_events_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (entry_id => entries.id)
#  fk_rails_...  (user_id => users.id)
#

class Event < ApplicationRecord
  include AccountScoped

  belongs_to :entry
  belongs_to :user, optional: true

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_action, ->(action) { where(action: action) }
  scope :chronological, -> { order(created_at: :asc) }

  # Common actions tracked
  ACTIONS = %w[
    triaged
    sent_back_to_triage
    gilded
    ungilded
    closed
    reopened
    postponed
    resumed
    created
    updated
  ].freeze

  def action_label
    I18n.t("events.actions.#{action}", default: action.humanize)
  end

  def particulars_display
    particulars.map { |k, v| "#{k}: #{v}" }.join(", ")
  end
end
