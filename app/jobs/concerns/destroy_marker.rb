# Marker in cache (Redis, condiviso web/Sidekiq) per segnalare nella UI
# admin un'eliminazione in corso. Scade da solo se il job muore; sugli
# errori transitori resta, così la riga continua a segnalare il retry.
module DestroyMarker
  extend ActiveSupport::Concern

  class_methods do
    def mark_destroying(id)
      Rails.cache.write(destroy_marker_key(id), true, expires_in: 1.hour)
    end

    def destroying?(id)
      Rails.cache.exist?(destroy_marker_key(id))
    end

    def destroy_marker_key(id)
      "admin:#{name.underscore}:#{id}"
    end
  end
end
