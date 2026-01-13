class Current < ActiveSupport::CurrentAttributes

  attribute :session, :user, :membership, :account
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

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

  def session=(value)
    super(value)

    if value.present?
      self.user = session.user
    end
  end

  def identity=(identity)
    super(identity)

    if identity.present?
      self.user = identity.users.find_by(account: account)
    end
  end

  def with_account(value, &)
    with(account: value, &)
  end

  def without_account(&)
    with(account: nil, &)
  end
end