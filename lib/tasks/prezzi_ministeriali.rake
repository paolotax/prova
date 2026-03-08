namespace :prezzi_ministeriali do
  desc "Popola prezzi ministeriali dalle import_adozioni. Uso: rails prezzi_ministeriali:popola[2025-2026]"
  task :popola, [:anno] => :environment do |_t, args|
    anno = args[:anno] || raise("Specificare anno scolastico, es: rails prezzi_ministeriali:popola[2025-2026]")

    puts "Estraggo prezzi ministeriali per #{anno} dalle import_adozioni..."
    count = PrezzoMinisteriale.popola_da_import_adozioni!(anno_scolastico: anno)
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
