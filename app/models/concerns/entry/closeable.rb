# frozen_string_literal: true

module Entry::Closeable
  extend ActiveSupport::Concern

  included do
    scope :recently_closed_first, -> { closed.order(closures: { created_at: :desc }) }
  end

  def close(user: Current.user)
    return if closed?

    transaction do
      not_now&.destroy
      create_closure!(user: user, account: account)
      track_event :closed
    end
  end

  def reopen(user: Current.user)
    return unless closed?

    transaction do
      closure.destroy
      track_event :reopened
    end
  end

  def closed?
    closure.present?
  end

  def open?
    !closed?
  end

  def closed_at
    closure&.created_at
  end

  def closed_by
    closure&.user
  end
end
