module Account::GestioneMandati
  extend ActiveSupport::Concern

  # Crea mandati per gli editori dati, su tutte le zone (o un sottoinsieme)
  def crea_mandati_per_editori!(editore_ids, zone_ids: nil)
    target_zone = zone.where(stato: "attiva")
    target_zone = target_zone.where(id: zone_ids) if zone_ids.present?

    editore_ids.each do |eid|
      target_zone.find_each do |zona|
        mandati.find_or_create_by!(
          editore_id: eid,
          provincia: zona.provincia,
          grado: zona.grado
        )
      end
    end
  end

  # Risolve editore_ids da params (singolo editore o intero gruppo)
  def editore_ids_per_mandato(gruppo:, editore_id: nil)
    if editore_id.present?
      [editore_id.to_i]
    else
      editori_da_adozioni.where(gruppo: gruppo).pluck(:id)
    end
  end

  # Editori che hanno adozioni per questo account
  def editori_da_adozioni
    nomi = adozioni.select(:editore).distinct.pluck(:editore)
    Editore.where(editore: nomi)
  end
end
