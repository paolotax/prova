json.extract! persona, :id, :cognome, :nome, :email, :cellulare, :telefono, :ruolo, :note, :scuola_id, :created_at, :updated_at
json.scuola persona.scuola&.denominazione
json.classi persona.classi.attive do |classe|
  json.id classe.id
  json.display classe.to_combobox_display
  json.anno_corso classe.anno_corso
end
json.appuntabile_value "Persona:#{persona.id}"
json.url persona_url(persona, format: :json)
