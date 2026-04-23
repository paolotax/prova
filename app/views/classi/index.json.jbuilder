json.ok true
json.total @total
json.count @classi.size

if @group_by_scuola
  json.data @classi.group_by(&:scuola) do |scuola, classi|
    json.scuola_id scuola.id
    json.denominazione scuola.denominazione
    json.comune scuola.comune
    json.provincia scuola.provincia
    json.classi classi do |classe|
      json.extract! classe, :id, :anno_corso, :sezione, :combinazione, :tipo_scuola, :numero_alunni
    end
  end
else
  json.data @classi do |classe|
    json.extract! classe, :id, :anno_corso, :sezione, :combinazione, :tipo_scuola, :numero_alunni
    json.scuola_id classe.scuola_id
    json.scuola_denominazione classe.scuola.denominazione
    json.scuola_comune classe.scuola.comune
    json.scuola_provincia classe.scuola.provincia
  end
end
