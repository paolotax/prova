namespace :controllo_adozioni do
  desc "Ricostruisce controllo_anomalie (scuola primaria EE). " \
       "Ripopola prima i prezzi di riferimento PrezzoMinisteriale dal dataset corrente."
  task rebuild: :environment do
    anno = Miur.anno_corrente
    Rails.logger.info "controllo_adozioni:rebuild — popola PrezzoMinisteriale #{anno} da miur_adozioni"
    n = PrezzoMinisteriale.popola!(anno: anno)
    Rails.logger.info "PrezzoMinisteriale #{anno}: #{n} prezzi di riferimento"

    tot = ControlloAdozioni::Rebuild.run!
    Rails.logger.info "controllo_anomalie: #{tot} anomalie"
    puts "PrezzoMinisteriale #{anno}: #{n} prezzi · controllo_anomalie: #{tot} anomalie"
  end
end
