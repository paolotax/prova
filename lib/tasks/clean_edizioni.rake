namespace :copertine do
  desc "Pulisce completamente EdizioneTitolo per ricominciare da zero"
  task clean_all: :environment do
    puts "=== PULIZIA COMPLETA EDIZIONI_TITOLI ==="
    puts ""
    puts "⚠️  ATTENZIONE: Questa operazione eliminerà tutti i record EdizioneTitolo"
    puts ""

    edizioni_count = EdizioneTitolo.count
    puts "Record da eliminare: #{edizioni_count}"
    puts ""

    print "Sei sicuro di voler continuare? (scrivi 'SI' per confermare): "
    confirmation = STDIN.gets.chomp

    unless confirmation == 'SI'
      puts "Operazione annullata"
      exit
    end

    puts ""
    puts "Eliminazione in corso..."

    # Elimina tutti gli EdizioneTitolo
    # Gli attachment verranno eliminati in cascata
    EdizioneTitolo.destroy_all

    puts ""
    puts "✅ Pulizia completata!"
    puts "EdizioneTitolo rimasti: #{EdizioneTitolo.count}"
    puts ""
    puts "Ora puoi ricaricare manualmente le copertine."
    puts "Quando carichi una copertina su un Libro, il callback"
    puts "creerà automaticamente l'EdizioneTitolo corrispondente."
  end
end
