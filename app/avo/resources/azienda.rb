class Avo::Resources::Azienda < Avo::BaseResource

  self.title =  :ragione_sociale
  self.includes = []
  # self.search: -> do
  #   scope.ransack(id_eq: params[:q], ragione_sociale_cont: params[:q], m: "or").result(distinct: false)
  # end

  def fields
    field :id, as: :id
    field :user, as: :belongs_to
    
    # Dati fiscali
    field :partita_iva, as: :text
    #,required: true
    #,placeholder: "11 cifre"
    #,format: -> { value&.upcase }
    # end

    field :codice_fiscale, as: :text
    #,required: true
    #,placeholder: "16 caratteri"
    #,format: -> { value&.upcase }
    # end

    field :ragione_sociale, as: :text, required: true
  
    field :regime_fiscale, 
      as: :select,
      options: {
        'RF01 - Ordinario': :rf01,
        'RF02 - Contribuenti minimi': :rf02,
        'RF04 - Agricoltura e attività connesse e pesca': :rf04,
        'RF05 - Vendita sali e tabacchi': :rf05,
        'RF06 - Commercio fiammiferi': :rf06,
        'RF07 - Editoria': :rf07,
        'RF08 - Gestione servizi telefonia pubblica':   :rf08,
        'RF09 - Rivendita documenti di trasporto pubblico e di sosta': :rf09,
        'RF10 - Intrattenimenti, giochi e altre attività di cui alla tariffa allegata al DPR 640/72': :rf10,
        'RF11 - Agenzie viaggi e turismo': :rf11,
        'RF12 - Agriturismo': :rf12,
        'RF13 - Vendite a domicilio': :rf13,
        'RF14 - Rivendita beni usati, oggetti d\'arte, d\'antiquariato o da collezione': :rf14,
        'RF15 - Agenzie di vendite all\'asta di oggetti d\'arte, antiquariato o da collezione': :rf15,
        'RF16 - IVA per cassa P.A.': :rf16,
        'RF17 - IVA per cassa': :rf17,
        'RF18 - Altro': :rf18,
        'RF19 - Regime forfettario': :rf19
      },
      display_with_value: false,
      placeholder: 'Choose the type of the container.'


    # Sede
    field :indirizzo, as: :text
    #,required: true
    # end

    field :cap, as: :text
    #,required: true
    #,placeholder: "5 cifre"
    # end

    field :comune, as: :text
    #,required: true
    # end

    field :provincia, as: :text
    #,required: true
    #,placeholder: "2 lettere"
    #,format: -> { value&.upcase }
    # end

    field :nazione, as: :text
    #,required: true
    #,default: 'IT'
    #,format: -> { value&.upcase }
    # end

    # Contatti
    field :email, as: :text
    #,required: true
    # end

    field :telefono, as: :text
    #,required: true
    # end

    field :indirizzo_telematico, as: :text
    #,required: true
    #,placeholder: "Codice SDI - 7 caratteri"
    # end

    # Dati bancari
    field :iban, as: :text
    #,format: -> { value&.upcase }
    # end

    field :banca, as: :text
    # end

    # field :created_at  #,as: :date_time
    # #,readonly: true
    # # end

    # field :updated_at  #,as: :date_time
    # #,readonly: true
    # # end
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

