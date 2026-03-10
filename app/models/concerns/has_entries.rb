module HasEntries
  extend ActiveSupport::Concern

  # Subclasses must implement:
  #   #entry_appunto_ids   -> array of appunto ids
  #   #entry_documento_ids -> array of documento ids
  #   #entry_tappa_ids     -> array of tappa ids (optional, defaults to [])

  def open_entries
    Entry.where(account: Current.account)
         .aperti
         .for_entryables(entry_appunto_ids, entry_documento_ids, entry_tappa_ids)
         .includes(:goldness, :closure, :not_now)
         .order(updated_at: :desc)
  end

  def closed_entries
    Entry.where(account: Current.account)
         .closed
         .for_entryables(entry_appunto_ids, entry_documento_ids, entry_tappa_ids)
         .includes(:goldness, :closure, :not_now)
         .order(updated_at: :desc)
  end

  private

  def entry_tappa_ids
    []
  end
end
