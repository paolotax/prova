json.partial! "documenti/documento", documento: @documento
json.righe @documento.documento_righe.includes(riga: :libro) do |doc_riga|
  riga = doc_riga.riga
  json.id riga.id
  json.libro_id riga.libro_id
  json.codice_isbn riga.libro&.codice_isbn
  json.titolo riga.libro&.titolo
  json.quantita riga.quantita
  json.prezzo_cents riga.prezzo_cents
  json.prezzo_copertina_cents riga.prezzo_copertina_cents
  json.sconto riga.sconto
  json.importo_cents riga.importo_cents
end
if @documento.documento_padre_id.present?
  json.documento_padre_id @documento.documento_padre_id
end
if @documento.documenti_derivati.any?
  json.documenti_derivati @documento.documenti_derivati do |d|
    json.id d.id
    json.causale d.causale&.causale
    json.numero_documento d.numero_documento
  end
end
