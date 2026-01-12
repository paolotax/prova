module NotNowable
  extend ActiveSupport::Concern

  included do
    has_one :not_now, as: :not_nowable, dependent: :destroy
  end

  def postpone(user: Current.user)
    create_not_now!(user: user) unless postponed?
  end

  def resume
    not_now&.destroy
  end

  def postponed?
    not_now.present?
  end
end
