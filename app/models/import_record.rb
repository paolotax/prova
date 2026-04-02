# frozen_string_literal: true

# == Schema Information
#
# Table name: import_records
#
#  id             :uuid             not null, primary key
#  completed_at   :datetime
#  error_messages :text             default([]), is an Array
#  errors_count   :integer          default(0)
#  import_type    :integer          not null
#  imported_count :integer          default(0)
#  metadata       :jsonb
#  started_at     :datetime
#  status         :integer          default("pending"), not null
#  updated_count  :integer          default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :uuid             not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_import_records_on_account_id                 (account_id)
#  index_import_records_on_account_id_and_created_at  (account_id,created_at)
#  index_import_records_on_user_id                    (user_id)
#  index_import_records_on_user_id_and_import_type    (user_id,import_type)
#
class ImportRecord < ApplicationRecord
  include AccountScoped
  broadcasts_refreshes

  belongs_to :user
  has_one_attached :file

  enum :import_type, {
    libri: 0,
    clienti: 1,
    documenti: 2,
    confezioni: 3,
    ministeriali: 4,
    insegnanti: 5
  }

  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  validates :import_type, presence: true
  validates :file, presence: true, on: :create

  scope :recent, -> { order(created_at: :desc) }

  def process!
    update_columns(status: self.class.statuses[:processing], started_at: Time.current)

    result = processor_class.new(file, user, metadata: metadata&.stringify_keys, account: account).call

    update_columns(
      status: result.success? ? self.class.statuses[:completed] : self.class.statuses[:failed],
      completed_at: Time.current,
      imported_count: result.imported_count,
      updated_count: result.updated_count,
      errors_count: result.errors_count,
      error_messages: result.errors.first(50),
      updated_at: Time.current
    )
  rescue StandardError => e
    update_columns(
      status: self.class.statuses[:failed],
      completed_at: Time.current,
      error_messages: [e.message],
      updated_at: Time.current
    )
    raise
  ensure
    broadcast_refresh rescue nil
  end

  def total_records
    imported_count + updated_count + errors_count
  end

  def success?
    completed? && errors_count.zero?
  end

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  private

  def processor_class
    "Imports::#{import_type.camelize}Processor".constantize
  end
end
