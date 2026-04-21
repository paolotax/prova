class RefreshMercatoNazionaleRollupJob < ApplicationJob
  queue_as :default

  # Refresh delle materialized view nazionali usate da AdozioniAnalytics.
  # Da invocare dopo un re-import di `import_adozioni` (post ministeriale).
  def perform
    AdozioniAnalytics.refresh_rollup!
  end
end
