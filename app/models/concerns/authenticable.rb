module Authenticable
  extend ActiveSupport::Concern

  included do
    # Passwordless authentication - no Devise modules needed
    # User authentication is handled via magic links and sessions

    validates :name, presence: true, uniqueness: true

    # Find user by name or email for login
    def self.find_by_login(login)
      where("lower(name) = :value OR lower(email) = :value", value: login.downcase).first
    end
  end
end