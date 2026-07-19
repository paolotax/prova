# frozen_string_literal: true

# Bulk checkboxes nelle card/righe appunti mandano entry.id quando disponibile,
# appunto.id altrimenti (vedi appunti/display/_preview.html.erb).
# Questo concern risolve sia gli entry id che gli appunto id in una scope di appunti.
module Appunti
  module BulkResolvable
    extend ActiveSupport::Concern

    private

    def bulk_appunti
      ids = Array(params[:ids]).compact_blank
      return current_account.appunti.none if ids.empty?

      current_account.appunti.where(<<~SQL.squish, appunto_ids: ids, entry_ids: ids)
        appunti.id IN (:appunto_ids)
        OR appunti.id IN (
          SELECT entries.entryable_id::uuid
          FROM entries
          WHERE entries.entryable_type = 'Appunto'
            AND entries.id IN (:entry_ids)
        )
      SQL
    end
  end
end
