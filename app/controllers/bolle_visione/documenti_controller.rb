class BolleVisione::DocumentiController < BolleVisione::BaseController
  CLIENTABLE_TYPES = %w[Classe Persona Scuola Cliente].freeze

  def create
    selection = parse_selection.slice(*CLIENTABLE_TYPES)

    if selection.empty? || selection.values.all? { |by_id| by_id.blank? }
      redirect_to bolla_visione_path(@bolla_visione), alert: "Seleziona almeno una riga." and return
    end

    documenti = []
    Documento.transaction do
      selection.each do |clientable_type, by_id|
        klass = clientable_type.constantize
        Hash(by_id).each do |clientable_id, riga_ids|
          clientable = scope_for(klass).find(clientable_id)
          righe = Current.account.bolla_visione_righe
            .where(id: Array(riga_ids).reject(&:blank?))
            .includes(:libro)
          next if righe.empty?

          documenti << Ritiro.new(@bolla_visione.scuola).crea_documento(
            righe: righe,
            causale: causale,
            clientable: clientable,
            data: params[:data_documento]
          )
        end
      end
    end

    redirect_to bolla_visione_path(@bolla_visione),
                notice: helpers.pluralize(documenti.size, "documento creato", plural: "documenti creati")
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, ArgumentError => e
    redirect_to bolla_visione_path(@bolla_visione), alert: "Errore: #{e.message}"
  end

  private

  def parse_selection
    raw = params[:selection_json].presence || params[:selection]
    return {} if raw.blank?
    return raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    JSON.parse(raw)
  rescue JSON::ParserError
    {}
  end

  def causale
    Causale.find_by(id: params[:causale_id]) or raise ArgumentError, "causale non trovata"
  end

  def scope_for(klass)
    case klass.name
    when "Persona", "Cliente", "Scuola" then Current.account.public_send(klass.name.downcase.pluralize)
    when "Classe" then Classe.joins(scuola: :account).where(accounts: { id: Current.account.id })
    else klass.all
    end
  end
end
