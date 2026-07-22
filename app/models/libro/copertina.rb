# frozen_string_literal: true

module Libro::Copertina
  extend ActiveSupport::Concern

  ALLOWED_COPERTINA_CONTENT_TYPES = %w[ image/jpeg image/png image/gif image/webp ].freeze
  MAX_COPERTINA_DIMENSIONS = { width: 4096, height: 4096 }.freeze

  included do
    has_one_attached :copertina,
                     service: ->(_libro) { Rails.env.production? ? :amazon_public : Rails.configuration.active_storage.service }

    validate :copertina_content_type_allowed, :copertina_dimensions_allowed, if: :copertina_attached?

    # Dopo il commit la copertina viene spostata sulla EdizioneTitolo condivisa per ISBN
    after_commit :sync_copertina_to_edizione_titolo, on: [:create, :update]

    # Flag per evitare loop infinito durante la sincronizzazione
    attr_accessor :skip_copertina_sync
  end

  def copertina_attached?
    copertina.attached?
  end

  # La copertina "vera" vive su EdizioneTitolo (condivisa per ISBN);
  # quella attaccata al libro è transitoria, in attesa del sync
  def copertina_effettiva
    if edizione_titolo&.copertina&.attached?
      edizione_titolo.copertina
    elsif copertina.attached?
      copertina
    end
  end

  def copertina_thumbnail
    blob = copertina_effettiva
    return unless blob

    blob.variable? ? blob.variant(resize_to_limit: [ 200, 267 ]) : blob
  end

  # For copertina SVG initials fallback
  def iniziali
    titolo.to_s.split.map(&:first).join[0..1].upcase
  end

  private

  def copertina_content_type_allowed
    unless ALLOWED_COPERTINA_CONTENT_TYPES.include?(copertina.content_type)
      errors.add(:copertina, "deve essere un'immagine JPEG, PNG, GIF o WebP")
    end
  end

  def copertina_dimensions_allowed
    return unless copertina.blob.analyzed? || safely_analyze_copertina_blob

    width = copertina.blob.metadata[:width]
    height = copertina.blob.metadata[:height]

    if width && width > MAX_COPERTINA_DIMENSIONS[:width]
      errors.add(:copertina, "larghezza deve essere inferiore a #{MAX_COPERTINA_DIMENSIONS[:width]}px")
    end

    if height && height > MAX_COPERTINA_DIMENSIONS[:height]
      errors.add(:copertina, "altezza deve essere inferiore a #{MAX_COPERTINA_DIMENSIONS[:height]}px")
    end
  end

  def safely_analyze_copertina_blob
    copertina.blob.analyze
  rescue ActiveStorage::FileNotFoundError
    false
  end

  def sync_copertina_to_edizione_titolo
    return if skip_copertina_sync
    return if codice_isbn.blank?
    return unless copertina.attached?

    edizione = EdizioneTitolo.find_or_initialize_by(codice_isbn: codice_isbn)
    edizione.titolo_originale ||= titolo

    # Sostituisci la copertina condivisa con quella nuova
    edizione.copertina.purge if edizione.copertina.attached?
    edizione.copertina.attach(copertina.blob)
    edizione.save!

    # Rimuovi la copertina dal libro dopo averla copiata su EdizioneTitolo
    self.skip_copertina_sync = true
    copertina.purge
    self.skip_copertina_sync = false
  rescue => e
    Rails.logger.error "Errore sync copertina per libro #{id}: #{e.message}"
  end
end
