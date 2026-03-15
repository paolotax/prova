# frozen_string_literal: true

class Appunti::AppuntoCreator
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Parametri appunto
  attribute :nome, :string
  attribute :content, :string
  attribute :appuntabile_value, :string
  attribute :telefono, :string
  attribute :email, :string
  attribute :publish, :boolean, default: false

  # Parametri persona
  attribute :persona_nome, :string
  attribute :persona_cognome, :string
  attribute :persona_cellulare, :string
  attribute :persona_email, :string
  attribute :persona_ruolo, :string
  attribute :persona_materia, :string
  attribute :persona_scuola_nome, :string

  attr_accessor :attachments
  attr_reader :appunto, :persona

  def create
    find_or_build_persona
    resolve_appuntabile
    build_appunto
    return false unless appunto.save

    maybe_publish
    appunto
  end

  private

  def find_or_build_persona
    return unless persona_params_present?

    @persona = find_persona_by_cellulare if persona_cellulare.present?

    @persona ||= Current.account.persone.build(
      nome: persona_nome,
      cognome: persona_cognome,
      cellulare: persona_cellulare,
      email: persona_email,
      ruolo: persona_ruolo.presence
    )

    link_persona_to_scuola if persona_scuola_nome.present? && @persona.scuola.blank?

    @persona.save! if @persona.new_record? || @persona.changed?
  end

  def find_persona_by_cellulare
    cleaned = persona_cellulare.gsub(/\s/, "")
    Current.account.persone.find_by("cellulare = :tel OR telefono = :tel", tel: cleaned)
  end

  def link_persona_to_scuola
    scuola = Current.account.scuole.search_all_word(persona_scuola_nome).first
    @persona.scuola = scuola if scuola
  rescue PgSearch::EmptyQueryError
    nil
  end

  def resolve_appuntabile
    explicit = Appuntabile.find_appuntabile(appuntabile_value) if appuntabile_value.present?

    if @persona
      link_persona_to_appuntabile(explicit) if explicit
      @resolved_appuntabile = @persona
    elsif explicit
      @resolved_appuntabile = explicit
    end
  end

  def link_persona_to_appuntabile(appuntabile)
    case appuntabile
    when Scuola
      @persona.scuola ||= appuntabile
    when Classe
      @persona.scuola ||= appuntabile.scuola
      unless @persona.classi.include?(appuntabile)
        @persona.persona_classi.build(classe: appuntabile, materia: persona_materia.presence)
      end
    end

    @persona.save! if @persona.changed? || @persona.persona_classi.any?(&:new_record?)
  end

  def build_appunto
    @appunto = Current.account.appunti.build(
      user: Current.user,
      nome: nome,
      content: content,
      telefono: telefono,
      email: email,
      appuntabile: @resolved_appuntabile
    )
    @appunto.attachments.attach(attachments) if attachments.present?
  end

  def maybe_publish
    appunto.publish if publish && appunto.persisted?
  end

  def persona_params_present?
    persona_cellulare.present? || persona_nome.present? || persona_cognome.present?
  end
end
