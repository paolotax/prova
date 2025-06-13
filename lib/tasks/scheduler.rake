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
      schedule = config[:scheduler][:schedule] || config['scheduler']['schedule']

      # Assicuriamoci che ogni job abbia un identificatore unico
      schedule.each do |job_name, job_config|
        job_config['unique'] = true
        job_config['unique_job_id'] = "#{job_name}_#{job_config['cron']}"
      end

      Sidekiq.schedule = schedule
      Sidekiq::Scheduler.reload_schedule!
      puts "[scheduler] Job schedulati ricaricati correttamente."
    else
      puts "[scheduler] ⚠️  File YAML non trovato: #{schedule_file}"
    end
  end

  desc "Elimina tutti i job schedulati da Redis"
  task clear: :environment do
    puts "[scheduler] Pulizia job schedulati da Redis..."
    Sidekiq::Scheduler.clear_schedule!
    puts "[scheduler] Schedule Redis pulito."
  end

  desc "Task per il deploy: pulisce e ricarica lo scheduler"
  task deploy: :environment do
    Rake::Task['scheduler:clear'].invoke
    Rake::Task['scheduler:reset'].invoke
  end
end
