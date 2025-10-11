# == Schema Information
#
# Table name: sconti
#
#  id                 :bigint           not null, primary key
#  data_fine          :date
#  data_inizio        :date             not null
#  percentuale_sconto :decimal(5, 2)    not null
#  scontabile_type    :string
#  tipo_sconto        :integer          default("vendita"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  categoria_id       :bigint
#  scontabile_id      :bigint
#  user_id            :bigint
#
# Indexes
#
#  index_sconti_on_categoria_id  (categoria_id)
#  index_sconti_on_scontabile    (scontabile_type,scontabile_id)
#  index_sconti_on_user_id       (user_id)
#  index_sconti_unique           (user_id,scontabile_type,scontabile_id,categoria_id,data_inizio,tipo_sconto) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (categoria_id => categorie.id)
#  fk_rails_...  (user_id => users.id)
#
class Sconto < ApplicationRecord
  belongs_to :user

  # Polymorphic association - può essere Cliente, Editore, o nil per sconti globali
  belongs_to :scontabile, polymorphic: true, optional: true

  # Se nil, lo sconto vale per tutte le categorie
  belongs_to :categoria, optional: true

  enum :tipo_sconto, { vendita: 0, acquisto: 1 }

  validates :percentuale_sconto, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :data_inizio, presence: true
  validates :user_id, presence: true
  validate :data_fine_dopo_data_inizio

  # Scope utili
  scope :attivi, -> { where("data_inizio <= ? AND (data_fine IS NULL OR data_fine >= ?)", Date.today, Date.today) }
  scope :per_cliente, ->(cliente) { where(scontabile: cliente, tipo_sconto: :vendita) }
  scope :per_editore, ->(editore) { where(scontabile: editore, tipo_sconto: :acquisto) }
  scope :per_categoria, ->(categoria) { where(categoria: categoria) }
  scope :globali, -> { where(scontabile_id: nil) }

  # Scope per trovare sconti applicabili a un'entità specifica
  scope :applicabili_a_cliente, ->(cliente_id) {
    where("(scontabile_type = 'Cliente' AND scontabile_id = ?) OR (scontabile_type = 'Cliente' AND scontabile_id IS NULL)", cliente_id)
  }

  scope :applicabili_a_editore, ->(editore_id) {
    where("(scontabile_type = 'Editore' AND scontabile_id = ?) OR (scontabile_type = 'Editore' AND scontabile_id IS NULL)", editore_id)
  }

  scope :applicabili_a_scuola, ->(scuola_id) {
    where("(scontabile_type = 'ImportScuola' AND scontabile_id = ?) OR (scontabile_type = 'ImportScuola' AND scontabile_id IS NULL)", scuola_id)
  }

  def to_s
    if scontabile.present?
      "#{percentuale_sconto}% - #{scontabile} - #{categoria&.nome_categoria || 'Tutte le categorie'}"
    elsif scontabile_type.present?
      tipo_text = case scontabile_type
                  when "Cliente" then "Tutti i clienti"
                  when "Editore" then "Tutti gli editori"
                  when "ImportScuola" then "Tutte le scuole"
                  else scontabile_type
                  end
      "#{percentuale_sconto}% - #{tipo_text} - #{categoria&.nome_categoria || 'Tutte le categorie'}"
    else
      "#{percentuale_sconto}% - Sconto globale - #{categoria&.nome_categoria || 'Tutte le categorie'}"
    end
  end

  def scontabile_description
    if scontabile.present?
      { type: scontabile_type, name: scontabile.to_s, scope: :specific }
    elsif scontabile_type.present?
      case scontabile_type
      when "Cliente"
        { type: "Cliente", name: "Tutti i clienti", scope: :all }
      when "Editore"
        { type: "Editore", name: "Tutti gli editori", scope: :all }
      when "ImportScuola"
        { type: "Scuola", name: "Tutte le scuole", scope: :all }
      else
        { type: scontabile_type, name: "Tutti", scope: :all }
      end
    else
      { type: nil, name: "Globale", scope: :global }
    end
  end

  def attivo?
    data_inizio <= Date.today && (data_fine.nil? || data_fine >= Date.today)
  end

  # Trova lo sconto più specifico applicabile per un libro e opzionalmente un'entità (cliente/scuola)
  def self.sconto_per_libro(libro:, cliente: nil, scuola: nil, user:)
    # Caso speciale: se il cliente è ImportScuola e il libro ha un prezzo_suggerito, usa sconto 0
    if scuola.present? && libro.prezzo_suggerito_cents.present? && libro.prezzo_suggerito_cents > 0
      return 0.0
    end

    categoria_id = libro.categoria_id

    # Determina l'entità (cliente o scuola)
    entity = cliente || scuola
    entity_type = cliente ? 'Cliente' : (scuola ? 'ImportScuola' : nil)

    if entity && entity_type
      # Con entità: cerca prima con categoria specifica, poi senza categoria
      # Priorità con categoria specifica:
      # 0. Entità specifica + categoria specifica
      # 1. Tutte le entità + categoria specifica
      # 2. Globale + categoria specifica
      # Priorità senza categoria (solo se non trovato con categoria):
      # 3. Entità specifica + tutte categorie
      # 4. Tutte le entità + tutte categorie
      # 5. Globale + tutte categorie

      # Prima cerca con categoria specifica
      sconto_con_categoria = user.sconti
        .attivi
        .vendita
        .where(categoria_id: categoria_id)
        .where(
          "(scontabile_type IS NULL OR scontabile_type = '') OR " \
          "(scontabile_type = ? AND (scontabile_id = ? OR scontabile_id IS NULL))",
          entity_type, entity.id
        )
        .order(
          Arel.sql(
            "CASE " \
              "WHEN scontabile_type = '#{entity_type}' AND scontabile_id = #{entity.id} THEN 0 " \
              "WHEN scontabile_type = '#{entity_type}' AND scontabile_id IS NULL THEN 1 " \
              "WHEN (scontabile_type IS NULL OR scontabile_type = '') THEN 2 " \
              "ELSE 3 " \
            "END"
          )
        )
        .first

      return sconto_con_categoria.percentuale_sconto.to_f if sconto_con_categoria

      # Se non trovato, cerca senza categoria (categoria_id IS NULL)
      sconto_generico = user.sconti
        .attivi
        .vendita
        .where(categoria_id: nil)
        .where(
          "(scontabile_type IS NULL OR scontabile_type = '') OR " \
          "(scontabile_type = ? AND (scontabile_id = ? OR scontabile_id IS NULL))",
          entity_type, entity.id
        )
        .order(
          Arel.sql(
            "CASE " \
              "WHEN scontabile_type = '#{entity_type}' AND scontabile_id = #{entity.id} THEN 0 " \
              "WHEN scontabile_type = '#{entity_type}' AND scontabile_id IS NULL THEN 1 " \
              "WHEN (scontabile_type IS NULL OR scontabile_type = '') THEN 2 " \
              "ELSE 3 " \
            "END"
          )
        )
        .first

      sconto_generico&.percentuale_sconto&.to_f || 0.0
    else
      # Senza entità: cerca solo sconti "tutti" e globali
      # Priorità:
      # 0. Tutti i clienti + categoria specifica
      # 1. Tutte le scuole + categoria specifica
      # 2. Globale + categoria specifica
      # 3. Tutti i clienti + tutte categorie
      # 4. Tutte le scuole + tutte categorie
      # 5. Globale + tutte categorie
      sconto = user.sconti
        .attivi
        .vendita
        .where("categoria_id = ? OR categoria_id IS NULL", categoria_id)
        .where(
          "(scontabile_type IS NULL OR scontabile_type = '') OR " \
          "(scontabile_type IN (?, ?) AND scontabile_id IS NULL)",
          'Cliente', 'ImportScuola'
        )
        .order(
          Arel.sql(
            "CASE " \
              "WHEN scontabile_type = 'Cliente' AND scontabile_id IS NULL AND categoria_id = #{categoria_id.to_i} THEN 0 " \
              "WHEN scontabile_type = 'ImportScuola' AND scontabile_id IS NULL AND categoria_id = #{categoria_id.to_i} THEN 1 " \
              "WHEN (scontabile_type IS NULL OR scontabile_type = '') AND categoria_id = #{categoria_id.to_i} THEN 2 " \
              "WHEN scontabile_type = 'Cliente' AND scontabile_id IS NULL AND categoria_id IS NULL THEN 3 " \
              "WHEN scontabile_type = 'ImportScuola' AND scontabile_id IS NULL AND categoria_id IS NULL THEN 4 " \
              "WHEN (scontabile_type IS NULL OR scontabile_type = '') AND categoria_id IS NULL THEN 5 " \
              "ELSE 6 " \
            "END"
          )
        )
        .first

      sconto&.percentuale_sconto&.to_f || 0.0
    end
  end

  private

  def data_fine_dopo_data_inizio
    return if data_fine.blank? || data_inizio.blank?

    if data_fine < data_inizio
      errors.add(:data_fine, "deve essere successiva alla data di inizio")
    end
  end
end
