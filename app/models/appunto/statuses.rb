module Appunto::Statuses
  extend ActiveSupport::Concern

  included do
    enum :status, %w[drafted published].index_by(&:itself)

    scope :published, -> { where(status: :published) }
    scope :drafted, -> { where(status: :drafted) }

    after_commit :broadcast_bozze_refresh, on: [:create, :destroy], if: :drafted?
    after_commit :broadcast_bozze_refresh, on: :update, if: :saved_change_to_status?
  end

  def broadcast_bozze_refresh
    Turbo::StreamsChannel.broadcast_refresh_later_to(user, "bozze")
  end

  def publish
    transaction do
      self.created_at = Time.current
      published!
    end
  end
end
