module HasDisponibilita
  extend ActiveSupport::Concern

  included do
    has_many :disponibilita, dependent: :destroy
    has_many :disponibilita_scuola, -> { where(user_id: nil) },
             class_name: "Disponibilita"
  end

  def orario_del_giorno(giorno_settimana)
    disponibilita.orari.where(giorno_settimana: giorno_settimana)
  end

  def chiusa_il?(data)
    return true if disponibilita.where(tipo: "chiusura", data: data).exists?
    return true if disponibilita.where(tipo: "patrono", ricorrente: true)
                                .where("EXTRACT(MONTH FROM data) = ? AND EXTRACT(DAY FROM data) = ?",
                                       data.month, data.day).exists?
    false
  end

  def sede_seggio?
    disponibilita.seggi.exists?
  end

  def riunioni_del_giorno(giorno_settimana)
    disponibilita.riunioni.where(giorno_settimana: giorno_settimana)
  end

  def indisponibilita_per(data)
    wday = data.wday
    disponibilita.where(tipo: "chiusura", data: data)
      .or(disponibilita.where(tipo: "patrono", ricorrente: true)
          .where("EXTRACT(MONTH FROM data) = ? AND EXTRACT(DAY FROM data) = ?",
                 data.month, data.day))
      .or(disponibilita.where(tipo: "riunione", giorno_settimana: wday))
  end

  def ha_orario?
    disponibilita.orari.exists?
  end
end
