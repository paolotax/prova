namespace :scheduler do
  desc "Pulisce lo schedule e lo ricarica da YAML"
  task reset: :environment do
    puts "[scheduler] Pulizia job schedulati da Redis..."
    Sidekiq::Scheduler.clear_schedule!
    puts "[scheduler] Schedule Redis pulito."

    schedule_file = Rails.root.join("config", "sidekiq.yml")

    if File.exist?(schedule_file)
      puts "[scheduler] Caricamento da #{schedule_file}..."
      Sidekiq::Scheduler.dynamic = true
      config = YAML.load_file(schedule_file)
      Sidekiq.schedule = config['scheduler']['schedule']
      Sidekiq::Scheduler.reload_schedule!
      puts "[scheduler] Job schedulati ricaricati correttamente."
    else
      puts "[scheduler] ⚠️  File YAML non trovato: #{schedule_file}"
    end
  end
end
