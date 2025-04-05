namespace :tappe do
  desc "Crea associazioni tappa_giro basate sui dati esistenti"
  task create_tappa_giro: :environment do
    puts "Inizio migrazione delle associazioni tappa-giro..."
    
    # Raggruppa le tappe per data_tappa e scuola/cliente
    Tappa.where.not(data_tappa: nil).all.group_by { |t| [t.data_tappa, t.tappable_id, t.tappable_type] }.each do |key, tappe|


      data_tappa, tappable_id, tappable_type = key
      
      # Crea una singola tappa per quella data e scuola/cliente
      tappa_principale = tappe.first
      
      # Raccogli tutti i giri associati a queste tappe
      giri_ids = tappe.map(&:giro_id).uniq.compact
      
      puts "Processando tappa del #{data_tappa} - #{giri_ids.size} giri trovati"
      
      # Crea le associazioni tappa_giro
      giri_ids.each do |giro_id|
        TappaGiro.find_or_create_by!(
          tappa_id: tappa_principale.id,
          giro_id: giro_id
        )
      end
      
      # Elimina le tappe duplicate (opzionale)
      if tappe.size > 1
        tappe[1..-1].each do |tappa_duplicata|
          puts "Eliminando tappa duplicata ID: #{tappa_duplicata.id}"
          tappa_duplicata.destroy
        end
      end
    end
    
    puts "Migrazione completata!"
  end
end