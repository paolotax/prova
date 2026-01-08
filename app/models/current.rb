class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :account
  attribute :membership
  attribute :session
  attribute :request_id

  def user=(user)
    super
  end

  def authenticated?
    user.present?
  end

  def member?
    membership.present?
  end

  def admin?
    membership&.admin? || membership&.owner?
  end

  def owner?
    membership&.owner?
  end
end