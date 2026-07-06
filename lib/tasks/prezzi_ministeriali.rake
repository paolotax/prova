namespace :prezzi_ministeriali do
  desc "Popola prezzi ministeriali dalle adozioni MIUR. Uso: rails prezzi_ministeriali:popola[202526]"
  task :popola, [:anno] => :environment do |_t, args|
    anno = args[:anno] || raise("Specificare anno scolastico MIUR, es: rails prezzi_ministeriali:popola[202526]")

    puts "Estraggo prezzi ministeriali per #{anno} da miur_adozioni..."
    count = PrezzoMinisteriale.popola!(anno: anno)
    puts "Inseriti/aggiornati #{count} prezzi ministeriali."

    puts "\nRiepilogo:"
    PrezzoMinisteriale.per_anno(anno).order(:classe, :disciplina).each do |pm|
      puts format("  Classe %s | %-55s | %6.2f €", pm.classe, pm.disciplina, pm.prezzo_cents / 100.0)
    end
  end

  desc "Mostra prezzi ministeriali correnti"
  task mostra: :environment do
    anno = PrezzoMinisteriale.anno_corrente
    if anno.nil?
      puts "Nessun prezzo ministeriale presente. Usa: rails prezzi_ministeriali:popola[2025-2026]"
      next
    end

    puts "Prezzi ministeriali #{anno}:\n\n"
    PrezzoMinisteriale.per_anno(anno).order(:classe, :disciplina).each do |pm|
      puts format("  Classe %s | %-55s | %6.2f €", pm.classe, pm.disciplina, pm.prezzo_cents / 100.0)
    end
  end
end
