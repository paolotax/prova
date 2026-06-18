# == Schema Information
#
# Table name: propagande
#
#  id         :uuid             not null, primary key
#  nome       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :uuid             not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_propagande_on_account_id  (account_id)
#  index_propagande_on_user_id     (user_id)
#
# Una propaganda (nome libero, es. "Propaganda 26") raggruppa i giri di un
# utente. Le bolle visione lasciate durante le tappe di quei giri sono il
# materiale da ritirare: l'andamento è organizzato per scuola × collana, coi
# titoli raggruppati per `gruppo` (vedi design 2026-06-14).
class Propaganda < ApplicationRecord
  self.table_name = "propagande"

  include AccountScoped

  belongs_to :user
  has_many :giri, dependent: :nullify

  validates :nome, presence: true

  # La propaganda corrente dell'utente (la più recente).
  def self.corrente(user:)
    where(user: user).order(created_at: :desc).first
  end

  def to_combobox_display
    nome
  end

  # Tappe dei giri della propaganda.
  def tappe
    Tappa.joins(:tappa_giri).where(tappa_giri: { giro_id: giri.select(:id) }).distinct
  end

  # Bolle visione lasciate durante la propaganda (via tappa → giro).
  def bolle_visione
    BollaVisione.where(tappa_id: tappe.select(:id))
  end

  # Scuole che hanno ricevuto bolle nella propaganda.
  def scuole
    Current.scuole
      .where(id: bolle_visione.select(:scuola_id))
      .order(:provincia, :denominazione)
  end

  # Riepilogo avanzamento: codici scuola distinct (totale vs completate) per
  # consegne (giri NON di ritiro) e ritiri (giro col titolo che contiene "Ritir").
  # "completate" = tappe già passate (data_tappa < oggi).
  def riepilogo
    ritiro_ids   = giri.select { |g| g.titolo.to_s.match?(/ritir/i) }.map(&:id)
    consegna_ids = giri.map(&:id) - ritiro_ids
    {
      consegne: conteggio_scuole(consegna_ids),
      ritiri:   conteggio_scuole(ritiro_ids)
    }
  end

  # Andamento per le scuole date: [Propaganda::Scuola, ...] con collane e residui.
  def andamento(scuole_list)
    scuole_list = scuole_list.to_a
    righe = righe_per(scuole_list.map(&:id))
    gruppo, posizione = gruppo_e_posizione(righe)
    collane = collane_by_id(righe)

    righe_per_scuola = righe.group_by { |r| r.bolla_visione.scuola_id }

    scuole_list.map do |scuola|
      Propaganda::Scuola.new(
        scuola: scuola,
        collane: collane_residuo(righe_per_scuola[scuola.id] || [], gruppo, posizione, collane)
      )
    end
  end

  private

  # Codici scuola distinct sulle tappe dei giri dati: { totale:, completate: }.
  def conteggio_scuole(giro_ids)
    return { totale: 0, completate: 0 } if giro_ids.empty?

    base = Tappa
      .joins(:tappa_giri)
      .joins("JOIN scuole ON scuole.id = tappe.tappable_id")
      .where(tappa_giri: { giro_id: giro_ids }, tappable_type: "Scuola")
      .where.not(scuole: { codice_ministeriale: [nil, ""] })

    {
      totale:     base.distinct.count("scuole.codice_ministeriale"),
      completate: base.completate.distinct.count("scuole.codice_ministeriale")
    }
  end

  def righe_per(scuola_ids)
    return [] if scuola_ids.empty?

    BollaVisioneRiga
      .where(bolla_visione_id: bolle_visione.where(scuola_id: scuola_ids).select(:id))
      .includes(:libro, :bolla_visione)
      .to_a
  end

  def collane_residuo(righe, gruppo, posizione, collane)
    righe.group_by { |r| r.bolla_visione.collana_id }.map do |collana_id, crs|
      voci = crs.map do |r|
        key = [collana_id, r.libro_id]
        Propaganda::Riga.new(
          titolo: r.libro&.titolo.to_s,
          quantita: r.quantita,
          esito: r.esito,
          gruppo: gruppo[key],
          position: posizione[key] || 9_999
        )
      end.sort_by { |v| [v.position, v.titolo] }

      Propaganda::Collana.new(collana: collane[collana_id], righe: voci)
    end.sort_by { |c| c.nome }
  end

  def gruppo_e_posizione(righe)
    collana_ids = righe.map { |r| r.bolla_visione.collana_id }.uniq
    gruppo = {}
    posizione = {}
    CollanaLibro.where(collana_id: collana_ids)
      .pluck(:collana_id, :libro_id, :gruppo, :position)
      .each do |collana_id, libro_id, g, pos|
        gruppo[[collana_id, libro_id]] = g
        posizione[[collana_id, libro_id]] = pos
      end
    [gruppo, posizione]
  end

  def collane_by_id(righe)
    ids = righe.map { |r| r.bolla_visione.collana_id }.uniq
    ::Collana.where(id: ids).index_by(&:id)
  end
end
