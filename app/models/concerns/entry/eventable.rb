# frozen_string_literal: true

module Entry::Eventable
  extend ActiveSupport::Concern

  def track_event(action, creator: Current.user, particulars: {})
    events.create!(
      action: action.to_s,
      user: creator,
      account: account,
      particulars: particulars
    )
    touch_last_active_at
  end

  def last_event
    events.recent.first
  end

  def events_for_action(action)
    events.for_action(action)
  end

  private

  def touch_last_active_at
    touch
  end
end
