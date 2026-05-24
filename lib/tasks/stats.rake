namespace :stats do
  desc "Classifica le Stat in produzione/lab in base a sorgente dati e healthcheck"
  task classifica: :environment do
    user = Stats::HealthcheckJob.new.send(:sentinel_user)
    abort "Nessun sentinel user trovato" unless user

    classificate = Hash.new(0)

    Stat.find_each do |stat|
      ok = stat.test_execution(user)
      usa_new = stat.testo.to_s.match?(/\bnew_adozioni\b/i)
      usa_import = stat.testo.to_s.match?(/\bimport_adozioni\b/i)

      nuovo_stato =
        if !ok
          "lab"
        elsif usa_new && !usa_import
          "produzione"
        else
          "lab"
        end

      stat.update_column(:stato, nuovo_stato)
      classificate[nuovo_stato] += 1
      puts "  ##{stat.id.to_s.rjust(3)} [#{stat.categoria.to_s.ljust(10)}] #{stat.titolo.to_s.truncate(40).ljust(40)} -> #{nuovo_stato}#{ok ? "" : " (errore: #{stat.ultimo_errore.to_s.truncate(60)})"}"
    end

    puts ""
    puts "Riepilogo:"
    classificate.sort.each { |stato, n| puts "  #{stato}: #{n}" }
  end

  desc "Sposta query operative (vendite/corrispettivi/info) nella categoria 'operativo'"
  task migra_categorie: :environment do
    operative_ids = [65, 66, 67, 69, 70, 71, 74]

    Stat.where(id: operative_ids).find_each do |stat|
      vecchia = stat.categoria
      stat.update_column(:categoria, "operativo")
      puts "  ##{stat.id} #{stat.titolo.to_s.truncate(40).ljust(40)}  #{vecchia} -> operativo"
    end

    puts ""
    puts "Stat ora in 'operativo': #{Stat.where(categoria: 'operativo').count}"
  end
end
