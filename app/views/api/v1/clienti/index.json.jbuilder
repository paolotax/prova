json.array! @clienti do |cliente|
  json.id cliente.id
  json.denominazione cliente.denominazione
  json.partita_iva cliente.partita_iva
  json.codice_fiscale cliente.codice_fiscale
  json.indirizzo cliente.indirizzo
  json.comune cliente.comune
  json.provincia cliente.provincia
  json.cap cliente.cap
  json.email cliente.email
  json.telefono cliente.telefono
  json.pec cliente.pec
  json.indirizzo_telematico cliente.indirizzo_telematico
end
