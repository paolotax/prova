json.extract! scuola, :id, :denominazione, :codice_ministeriale, :indirizzo, :cap, :comune, :provincia, :regione, :tipo_scuola, :email, :pec, :telefono, :note, :classi_count, :adozioni_count, :created_at, :updated_at
json.url scuola_url(scuola, format: :json)
