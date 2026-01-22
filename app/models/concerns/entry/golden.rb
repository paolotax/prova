# frozen_string_literal: true

module Entry::Golden
  extend ActiveSupport::Concern

  def gild(user: Current.user)
    return if golden?
    return if closed?  # Cannot gild closed entries

    transaction do
      create_goldness!(user: user, account: account)
      track_event :gilded
    end
  end

  def ungild
    return unless golden?

    transaction do
      goldness.destroy
      track_event :ungilded
    end
  end

  def golden?
    goldness.present?
  end

  def gilded_at
    goldness&.created_at
  end

  def gilded_by
    goldness&.user
  end
end
