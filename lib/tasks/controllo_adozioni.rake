namespace :controllo_adozioni do
  desc "Ricostruisce controllo_anomalie (scuola primaria EE). " \
       "Ripopola prima i prezzi di riferimento PrezzoMinisteriale dal dataset corrente."
  task rebuild: :environment do
    anno = PrezzoMinisteriale.anno_scolastico_corrente
    Rails.logger.info "controllo_adozioni:rebuild — popola PrezzoMinisteriale #{anno} da new_adozioni"
    n = PrezzoMinisteriale.popola_da_new_adozioni!(anno_scolastico: anno)
    Rails.logger.info "PrezzoMinisteriale #{anno}: #{n} prezzi di riferimento"

    tot = ControlloAdozioni::Rebuild.run!
    Rails.logger.info "controllo_anomalie: #{tot} anomalie"
    puts "PrezzoMinisteriale #{anno}: #{n} prezzi · controllo_anomalie: #{tot} anomalie"
  end
end
