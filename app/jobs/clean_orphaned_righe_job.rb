class CleanOrphanedRigheJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "CleanOrphanedRigheJob started at #{Time.current}"

    # Find orphaned righe
    orphaned = Riga.left_joins(:documento_righe)
                   .where(documento_righe: { id: nil })
                   .includes(:libro)

    count = orphaned.count

    Rails.logger.info "Found #{count} orphaned Riga records"

    return if count.zero?

    # Save backup to CSV
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_file = Rails.root.join('tmp', "orphaned_righe_#{timestamp}.csv")

    Rails.logger.info "Saving backup to: #{backup_file}"

    require 'csv'
    CSV.open(backup_file, 'w') do |csv|
      csv << ['riga_id', 'libro_id', 'isbn', 'titolo', 'quantita', 'prezzo_cents', 'sconto', 'created_at', 'updated_at']

      orphaned.find_each do |riga|
        csv << [
          riga.id,
          riga.libro_id,
          riga.libro&.codice_isbn,
          riga.libro&.titolo,
          riga.quantita,
          riga.prezzo_cents,
          riga.sconto,
          riga.created_at,
          riga.updated_at
        ]
      end
    end

    # Delete orphaned righe
    deleted_count = orphaned.delete_all

    Rails.logger.info "Deleted #{deleted_count} orphaned Riga records"
    Rails.logger.info "Backup saved to: #{backup_file}"
    Rails.logger.info "CleanOrphanedRigheJob completed at #{Time.current}"

    # Optional: send notification or alert if too many orphaned records
    if deleted_count > 100
      Rails.logger.warn "Warning: #{deleted_count} orphaned righe were deleted. This might indicate a problem."
    end
  end
end
