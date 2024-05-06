json.extract! profile, :id, :user_id, :nome, :cognome, :ragione_sociale, :indirizzo, :cap, :citta, :cellulare, :email, :iban, :nome_banca, :created_at, :updated_at
json.url profile_url(profile, format: :json)
