class Avo::Resources::Azienda < Avo::BaseResource

  # self.title = :ragione_sociale
  # self.includes = []
  # self.search = -> do
  #   scope.ransack(id_eq: params[:q], ragione_sociale_cont: params[:q], m: "or").result(distinct: false)
  # end

  def fields
    field :id, as: :id
    field :user, as: :belongs_to
    
    # Dati fiscali
    field :partita_iva

    field :codice_fiscale

    field :ragione_sociale
    
    field :regime_fiscale do |field|
      field.as = :select
      field.required = true
      field.options = {
        'Ordinario': :rf01,
        'Contribuenti minimi': :rf02,
        'Agricoltura e pesca': :rf04,
        'Vendita sali e tabacchi': :rf05,
        'Commercio fiammiferi': :rf06,
        'Editoria': :rf07,
        'Gestione telefonia pubblica': :rf08,
        'Rivendita trasporto pubblico': :rf09,
        'Intrattenimenti e giochi': :rf10,
        'Agenzie viaggi': :rf11,
        'Agriturismo': :rf12,
        'Vendite a domicilio': :rf13,
        'Rivendita beni usati': :rf14,
        'Agenzie d\'asta': :rf15,
        'IVA per cassa P.A.': :rf16,
        'IVA per cassa': :rf17,
        'Altro': :rf18,
        'Regime forfettario': :rf19
      }
    end

    # Sede
    field :indirizzo

    field :cap

    field :comune

    field :provincia

    field :nazione

    # Contatti
    field :email

    field :telefono

    field :indirizzo_telematico # do |field|
    #   field.as = :text
    #   field.required = true
    #   field.placeholder = "Codice SDI - 7 caratteri"
    # end

    # Dati bancari
    field :iban do |field|
      field.as = :text
      field.format = -> { value&.upcase }
    end

    field :banca do |field|
      field.as = :text
    end

    field :created_at do |field|
      field.as = :date_time
      field.readonly = true
    end

    field :updated_at do |field|
      field.as = :date_time
      field.readonly = true
    end
  end

  # Validazioni custom
  def validate_creation
    validate_length :partita_iva, is: 11
    validate_length :codice_fiscale, is: 16
    validate_length :cap, is: 5
    validate_length :provincia, is: 2
    validate_length :nazione, is: 2
    validate_length :indirizzo_telematico, is: 7
    validate_length :iban, is: 27, allow_blank: true
  end

  def validate_update
    validate_length :partita_iva, is: 11
    validate_length :codice_fiscale, is: 16
    validate_length :cap, is: 5
    validate_length :provincia, is: 2
    validate_length :nazione, is: 2
    validate_length :indirizzo_telematico, is: 7
    validate_length :iban, is: 27, allow_blank: true
  end

  # Filtri
  def filters
    filter Avo::Filters::RegimeFiscaleFilter
    filter Avo::Filters::UserFilter
  end
end

