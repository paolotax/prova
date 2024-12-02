class GeocodeClienteJob
  include Sidekiq::Job

  def perform(cliente_id)
    cliente = Cliente.find(cliente_id)
    cliente.geocode
    cliente.geocoded = true
    cliente.save
  end
end

