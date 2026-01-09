class AuthCleanupJob < ApplicationJob
  queue_as :default

  def perform
    cleanup_expired_sessions
    cleanup_expired_magic_links
  end

  private

  def cleanup_expired_sessions
    count = Session.expired.delete_all
    Rails.logger.info "[AuthCleanupJob] Deleted #{count} expired sessions"
  end

  def cleanup_expired_magic_links
    count = MagicLink.cleanup_expired
    Rails.logger.info "[AuthCleanupJob] Deleted #{count} expired magic links"
  end
end
