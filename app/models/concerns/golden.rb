module Golden
  extend ActiveSupport::Concern

  included do
    has_one :goldness, as: :goldenable, dependent: :destroy
  end

  def mark_golden(user: Current.user)
    create_goldness!(user: user) unless golden?
  end

  def unmark_golden
    goldness&.destroy
  end

  def golden?
    goldness.present?
  end
end
