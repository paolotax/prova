module Consegnabile
  extend ActiveSupport::Concern

  included do
    has_many :consegne, as: :consegnabile, dependent: :destroy
  end

  # Fast path: un click consegna tutti i residui
  def mark_consegnato(user: Current.user, consegnato_il: nil)
    return if consegnato?
    guard_consegna_applicabile!

    transaction do
      consegna = consegne.create!(user: user, consegnato_il: consegnato_il || Time.current)
      residui_per_documento_riga.each do |documento_riga_id, quantita|
        consegna.consegna_righe.create!(documento_riga_id: documento_riga_id, quantita: quantita)
      end
    end
    dopo_variazione_consegne
  end

  # Consegna solo le quantità indicate: { documento_riga_id => quantita }
  def consegna_parziale!(quantita_per_documento_riga, user: Current.user, consegnato_il: nil)
    guard_consegna_applicabile!

    da_consegnare = quantita_per_documento_riga.to_h { |k, v| [k.to_s, v.to_i] }
                                               .select { |_, quantita| quantita.positive? }
    raise ArgumentError, "nessuna quantità da consegnare" if da_consegnare.empty?

    residui = residui_per_documento_riga.transform_keys(&:to_s)
    da_consegnare.each do |documento_riga_id, quantita|
      residuo = residui.fetch(documento_riga_id, 0)
      if quantita > residuo
        raise ArgumentError, "quantità #{quantita} oltre il residuo #{residuo} (documento_riga #{documento_riga_id})"
      end
    end

    consegna = nil
    transaction do
      consegna = consegne.create!(user: user, consegnato_il: consegnato_il || Time.current)
      da_consegnare.each do |documento_riga_id, quantita|
        consegna.consegna_righe.create!(documento_riga_id: documento_riga_id, quantita: quantita)
      end
    end
    dopo_variazione_consegne
    consegna
  end

  def unmark_consegnato(consegna = nil)
    (consegna || consegne.order(:consegnato_il).last)&.destroy
    dopo_variazione_consegne
  end

  def consegnato?
    consegne.any? && copie_residue_da_consegnare.zero?
  end

  def parzialmente_consegnato?
    consegne.any? && copie_residue_da_consegnare.positive?
  end

  def consegnato_il
    consegne.maximum(:consegnato_il)
  end

  def copie_residue_da_consegnare
    residui_per_documento_riga.values.sum
  end

  def copie_consegnate
    ConsegnaRiga.joins(:consegna)
      .where(consegne: { consegnabile_type: self.class.base_class.name, consegnabile_id: id })
      .sum(:quantita)
  end

  # { documento_riga_id => residuo }, solo righe con residuo positivo
  def residui_per_documento_riga
    @residui_per_documento_riga ||= begin
      consegnate = ConsegnaRiga.joins(:consegna)
        .where(consegne: { consegnabile_type: self.class.base_class.name, consegnabile_id: id })
        .group(:documento_riga_id)
        .sum(:quantita)

      documento_righe.joins(:riga).pluck(:id, Arel.sql("righe.quantita"))
        .each_with_object({}) do |(documento_riga_id, quantita), residui|
          residuo = quantita - consegnate.fetch(documento_riga_id, 0)
          residui[documento_riga_id] = residuo if residuo.positive?
        end
    end
  end

  private

  def guard_consegna_applicabile!
    if respond_to?(:consegna_applicabile?) && !consegna_applicabile?
      raise ArgumentError, "consegna non applicabile per questa causale"
    end
  end

  def dopo_variazione_consegne
    consegne.reset
    @residui_per_documento_riga = nil
    ricalcola_saldo_clientable
    ricalcola_giacenze_libri if respond_to?(:ricalcola_giacenze_libri)
    auto_close_se_completo if respond_to?(:auto_close_se_completo)
  end

  def ricalcola_saldo_clientable
    clientable = try(:clientable)
    clientable.ricalcola_saldo! if clientable.respond_to?(:ricalcola_saldo!)
  end
end
