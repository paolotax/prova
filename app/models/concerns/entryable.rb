# frozen_string_literal: true

# Concern for models that can be entryables (delegated types)
# Include in: Appunto, Documento, Tappa
#
# This concern provides:
# - Association to Entry (the unified triage record)
# - Delegation of triage-related methods to Entry
# - Auto-creation of Entry when needed
#
module Entryable
  extend ActiveSupport::Concern

  included do
    # The polymorphic association to Entry
    # Note: Entry stores entryable_id as string to handle both UUID and bigint
    has_one :entry, as: :entryable, dependent: :destroy

    # After create callback to auto-create entry if desired
    after_create :create_entry_record, if: :should_auto_create_entry?
  end

  # Delegate triage state methods to entry
  delegate :column, :giro, :golden?, :closed?, :postponed?, :active?,
           :triaged?, :awaiting_triage?, :gilded_at, :closed_at, :postponed_at,
           to: :entry, allow_nil: true

  # Delegate triage actions to entry
  delegate :triage_into, :send_back_to_triage, :move_to_column,
           :gild, :ungild, :close, :reopen, :postpone, :resume,
           to: :entry, allow_nil: true

  # Delegate event tracking to entry
  delegate :track_event, :events, to: :entry, allow_nil: true

  # Create entry automatically if it doesn't exist
  def ensure_entry!(user: nil, account: nil)
    return entry if entry.present?

    create_entry!(
      user: user || entry_user,
      account: account || entry_account,
      giro_id: entry_giro_id
    )
  end

  # Find or build entry
  def find_or_build_entry
    entry || build_entry(
      user: entry_user,
      account: entry_account,
      giro_id: entry_giro_id
    )
  end

  private

  # Override these in the including model if needed
  def should_auto_create_entry?
    # By default, don't auto-create (preserves backward compatibility)
    false
  end

  def create_entry_record
    create_entry!(
      user: entry_user,
      account: entry_account,
      giro_id: entry_giro_id
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Could not create entry for #{self.class.name}##{id}: #{e.message}"
  end

  # Methods to get entry attributes - override in model if attribute names differ
  def entry_user
    respond_to?(:user) ? user : Current.user
  end

  def entry_account
    respond_to?(:account) ? account : Current.account
  end

  def entry_giro_id
    # Only Tappa has giro_id by default
    respond_to?(:giro_id) ? giro_id : nil
  end
end
