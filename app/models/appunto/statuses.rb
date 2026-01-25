module Appunto::Statuses
  extend ActiveSupport::Concern

  included do
    enum :status, %w[drafted published].index_by(&:itself)

    scope :published, -> { where(status: :published) }
    scope :drafted, -> { where(status: :drafted) }
  end

  def publish
    transaction do
      self.created_at = Time.current
      published!
    end
  end
end
