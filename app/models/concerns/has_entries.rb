module HasEntries
  extend ActiveSupport::Concern

  # Subclasses must implement:
  #   #entry_appunto_ids  -> array of appunto ids
  #   #entry_documento_ids -> array of documento ids

  def open_entries
    Entry.where(account: Current.account)
         .aperti
         .for_entryables(entry_appunto_ids, entry_documento_ids)
         .includes(:goldness, :closure, :not_now)
         .order(updated_at: :desc)
  end

  def closed_entries
    Entry.where(account: Current.account)
         .closed
         .for_entryables(entry_appunto_ids, entry_documento_ids)
         .includes(:goldness, :closure, :not_now)
         .order(updated_at: :desc)
  end
end
