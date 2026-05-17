# frozen_string_literal: true

# Bulk checkboxes nelle card documenti mandano entry.id quando disponibile,
# documento.id altrimenti (vedi documenti/display/_preview.html.erb).
# Questo concern risolve sia gli entry id che i documento id in una scope di documenti.
module Documenti
  module BulkResolvable
    extend ActiveSupport::Concern

    private

    def bulk_documenti
      ids = Array(params[:ids]).compact_blank
      return current_account.documenti.none if ids.empty?

      current_account.documenti.where(<<~SQL.squish, doc_ids: ids, entry_ids: ids)
        documenti.id IN (:doc_ids)
        OR documenti.id IN (
          SELECT entries.entryable_id::uuid
          FROM entries
          WHERE entries.entryable_type = 'Documento'
            AND entries.id IN (:entry_ids)
        )
      SQL
    end
  end
end
