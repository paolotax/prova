class GeocodeImportScuolaJob
  include Sidekiq::Job

  def perform(import_scuola_id)
    import_scuola = ImportScuola.find(import_scuola_id)
    import_scuola.geocode
    import_scuola.save
  end
end