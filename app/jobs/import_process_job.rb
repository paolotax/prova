# frozen_string_literal: true

class ImportProcessJob < ApplicationJob
  queue_as :default

  def perform(import_record_id)
    import_record = ImportRecord.find(import_record_id)
    import_record.process!
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "ImportProcessJob: ImportRecord #{import_record_id} not found"
  end
end
