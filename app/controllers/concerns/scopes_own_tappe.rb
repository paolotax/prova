module ScopesOwnTappe
  extend ActiveSupport::Concern

  private

  # Le tappe sono per-utente: nelle viste account-wide (dashboard, kanban,
  # postponed, closed) un membro deve vedere solo le proprie tappe, ma
  # comunque appunti e documenti di tutto il team.
  def filter_own_tappe(scope)
    scope.where("entries.entryable_type <> 'Tappa' OR entries.entryable_id IN (?)",
                current_user.tappe.where(account: current_account).pluck(:id).presence || [""])
  end
end
