# frozen_string_literal: true

module Entry::Postponable
  extend ActiveSupport::Concern

  def postpone(user: Current.user)
    return if postponed?

    transaction do
      send_back_to_triage
      create_not_now!(user: user, account: account)
      track_event :postponed
    end
  end

  def resume
    return unless postponed?

    transaction do
      not_now.destroy
      track_event :resumed
    end
  end

  def postponed?
    not_now.present?
  end

  def active?
    open? && !postponed?
  end

  def postponed_at
    not_now&.created_at
  end

  def postponed_by
    not_now&.user
  end
end
