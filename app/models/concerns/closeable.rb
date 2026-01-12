module Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, as: :closeable, dependent: :destroy
  end

  def close(user: Current.user)
    create_closure!(user: user) unless closed?
  end

  def reopen
    closure&.destroy
  end

  def closed?
    closure.present?
  end

  def open?
    !closed?
  end
end
