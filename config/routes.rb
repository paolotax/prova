# first, setup dashboard authentication
require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  # Letter opener web for viewing emails in development
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if defined?(LetterOpenerWeb)

  namespace :my do
    resource :menu
  end

  # =========================================
  # AUTENTICAZIONE (senza contesto account)
  # =========================================

  # Passwordless authentication
  resources :magic_links, only: %i[new create] do
    collection do
      get :sent
      post :authenticate
      get 'verify/:code', action: :verify, as: :verify
    end
  end

  namespace :passwordless do
    resources :sessions, only: %i[index destroy] do
      collection do
        delete :destroy_all
      end
    end
  end

  delete 'logout', to: 'passwordless/sessions#logout', as: :logout

  # =========================================
  # SELEZIONE ACCOUNT
  # =========================================

  resources :accounts, only: %i[index new create]

  resources :users do
    scope module: :users do
      resource :personal_info
      resource :avatar
      post :send_setup_mail, controller: "setup_mails"
    end
  end

  # =========================================
  # ADMIN ROUTES (con autenticazione admin)
  # =========================================

  constraints lambda { |request|
    token = request.cookie_jar.signed[:session_token]
    session = Session.active.find_by(token: token) if token.present?
    session&.user&.admin?
  } do
    mount Blazer::Engine, at: 'blazer' if defined?(Blazer)
    mount RailsPerformance::Engine, at: 'rails/performance' if defined?(RailsPerformance)
    mount Sidekiq::Web => '/sidekiq'
    mount Motor::Admin => '/motor' if defined?(Motor)
    mount RailsDesigner::Engine, at: '/rails_designer' if defined?(RailsDesigner)

    namespace :admin do
      root 'dashboard#index'
      resources :extension_mails, only: %i[index create]
      resources :cli_mails, only: %i[index create]
      resources :account_invitations, only: %i[index create]
    end
  end

  # Download estensione Chrome (link pubblico per email)
  get 'download/extension', to: 'downloads#extension', as: :download_extension

  # Informazioni legali pubbliche
  get "privacy", to: "legal#privacy", as: :privacy
  get "fonti-e-licenze", to: "legal#data_sources", as: :data_sources

  # =========================================
  # MOBILE (sessione, senza account scope in URL)
  # =========================================
  namespace :mobile, path: 'm' do
    resources :appunti, only: %i[new create], path_names: { new: 'nuovo' }
  end

  # =========================================
  # ROUTES CON CONTESTO ACCOUNT
  # =========================================

  scope '/:account_id', constraints: { account_id: /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/ } do
    # Dashboard account
    root 'dashboard#index', as: :account_root

    # =========================================
    # TRIAGE SYSTEM
    # =========================================

    # Unified triage dashboard
    get 'dashboard', to: 'dashboard#index'

    # Dashboard columns (for lazy loading with pagination)
    namespace :dashboard do
      namespace :columns do
        resource :postponed, only: :show
        resource :closed, only: :show
      end
      resources :columns, only: :show
    end

    # Bulk actions per entries
    namespace :entries do
      resource :prints, only: [:create]
      resource :bulk_gestione, only: [:show], controller: 'bulk_gestione'
      resource :bulk_stati, only: [:create], controller: 'bulk_stati'
      resource :deletions, only: [:create]
    end

    # Entries (unified triage items)
    resources :entries, only: %i[index show] do
      scope module: :entries do
        resource :triage,    only: %i[create destroy]
        resource :goldness,  only: %i[create destroy]
        resource :closure,   only: %i[create destroy]
        resource :not_now,   only: %i[create destroy]
      end
    end

    # Columns (triage phases)
    resources :columns do
      resource :left_position, only: :create, module: :columns
      resource :right_position, only: :create, module: :columns
    end

    # Filtri salvati
    resources :filters, only: %i[create destroy]

    namespace :filters do
      resource :settings_refresh, only: :create
    end

    # =========================================
    # GESTIONE ACCOUNT (namespace accounts)
    # =========================================
    namespace :accounts, path: '' do
      resource :configurazione, only: [:show], controller: 'configurazione'
      resource :azienda, only: %i[show new create edit update]

      resources :zone, only: %i[index new create destroy] do
        collection do
          resource :importazione, only: [:create], controller: 'zone/importazioni'
        end
      end

      resources :mandati, only: %i[index new create update destroy] do
        resource :disdetta, only: %i[create destroy], module: :mandati
      end

      namespace :mandati do
        resources :gruppi, only: [:destroy], param: :id do
          resource :disdetta, only: %i[create destroy], module: :gruppi
        end
        resource :sincronizzazione_adozioni, only: [:create]
      end

      resources :members, only: %i[create update destroy] do
        scope module: :members do
          resources :scuole, only: %i[create destroy], controller: 'membership_scuole'
          resource :bulk_scuole, only: %i[create destroy], controller: 'bulk_membership_scuole'
        end
      end

      resource :distribuzione, only: [:show], controller: 'distribuzione' do
        resource :assegnazione, only: [:create], controller: 'distribuzione/assegnazioni'
      end

      resources :aree, only: [:show], param: :provincia do
        resource :assegnazione, only: [:create], controller: 'aree/assegnazioni'
        resources :mandati, only: %i[create destroy], controller: 'aree/mandati', param: :gruppo
      end
    end

    # Chats
    resources :chats do
      resources :messages, only: [:create]
    end

    resources :models, only: %i[index show] do
      collection do
        post :refresh
      end
    end

    resources :voice_notes do
      member do
        post :transcribe
        post :create_note_from_transcript
      end
    end

    # Agenda
    get 'agenda/planner', to: 'agenda#planner', as: 'agenda_planner'
    get 'agenda', to: 'agenda#index'
    get 'agenda/:giorno', to: 'agenda#show', as: 'giorno'
    get 'agenda/:giorno/mappa', to: 'agenda#mappa', as: 'mappa_del_giorno'
    get 'agenda/:giorno/adozioni_tappe.pdf', to: 'agenda#adozioni_tappe_pdf', as: 'adozioni_tappe_pdf'
    get 'agenda/:giorno/tappe_giorno.pdf', to: 'agenda#tappe_giorno_pdf', as: 'tappe_giorno_pdf'
    get 'agenda/:giorno/dettaglio_appunti_documenti.pdf', to: 'agenda#dettaglio_appunti_documenti_pdf',
                                                          as: 'dettaglio_appunti_documenti_pdf'
    get 'agenda/:giorno/fogli_scuola_tappe.pdf', to: 'agenda#fogli_scuola_tappe_pdf', as: 'fogli_scuola_tappe_pdf'

    resource :search, only: [:show], controller: 'search'

    # Ricerca unificata destinatari per combobox appunti
    resources :destinatari, only: [:index]

    resources :clienti do
      scope module: :clienti do
        resource :entries, only: [:show]
        resource :closed_entries, only: [:show]
      end
      resources :sconti, only: %i[index new create edit update destroy]
    end

    namespace :clienti do
      resource :prints, only: [:create]
      resource :bulk_tappe, only: [:create]
      resource :deletions, only: [:create]
    end

    # Bulk actions per documenti (deve essere PRIMA di resources :documenti)
    namespace :documenti do
      resource :prints, only: [:create]
      resource :duplications, only: [:create]
      resource :deletions, only: [:create]
      resource :bulk_gestione, only: [:show], controller: 'bulk_gestione'
      resource :bulk_consegne, only: %i[create destroy]
      resource :bulk_pagamenti, only: %i[create destroy]
      resource :bulk_derivazioni, only: [:create], controller: 'bulk_derivazioni'
      resource :bulk_stati, only: [:create], controller: 'bulk_stati'
    end

    resources :documenti do
      resources :documento_righe, only: %i[new create], controller: 'documento_righe'
      scope module: :documenti do
        resources :righe, only: [:create]
        resource :export, only: [:show]
        resource :consegna, only: %i[create update destroy], controller: 'consegna'
        resource :pagamento, only: %i[create update destroy], controller: 'pagamento'
        resource :derivazione, only: %i[create destroy], controller: 'derivazione'
        resource :collegamento, only: [:create], controller: 'collegamento'
      end
      collection do
        get 'filtra'
        get 'vendite'
      end
      member do
        # Legacy routes for compatibility
        get :esporta_xml, to: 'documenti/exports#show'
        patch :update_righe, to: 'documenti/righe#create'
      end
    end

    # Singular resource for next documento number
    resource :documento_numero, only: [:show], controller: 'documenti/numeri'

    resources :causali

    resources :documento_righe, only: %i[new show edit update destroy] do
      member do
        patch 'update_posizione'
      end
    end

    resources :titoli, only: [:show], param: :codice_isbn

    # Unified imports
    resources :imports, only: %i[new create show]

    # Temporary: keep export_confezioni until fully migrated
    resources :libri_importer, only: [] do
      collection do
        get 'export_confezioni'
      end
    end

    get 'classi/:id', to: 'classi#show', as: 'classe'
    get 'classi',     to: 'classi#index', as: 'classi', defaults: { format: :json }

    get 'filter_options/:resource', to: 'filter_options#show', as: 'filter_options', defaults: { format: :json }

    resources :classe_chips, only: :create, param: :combobox_value
    resources :libro_chips,  only: :create, param: :combobox_value
    resources :giro_chips, only: :create, param: :combobox_value

    namespace :libri do
      resource :prints, only: [:create]
      resource :deletions, only: [:create]
      resource :carrello, only: %i[create update]
      resource :confezioni, only: [:create]
      resource :bulk_updates, only: [:update]
    end

    resources :vendite, only: [:index]

    resources :libri do
      collection do
        get 'situazione'
        get 'scarico_fascicoli'
      end
      member do
        get 'get_prezzo_e_sconto'
      end
      scope module: :libri do
        resources :fascicoli, only: %i[index create destroy]
      end
      resource :movimenti, only: [:show], module: :libri
      resources :qrcodes
    end

    resources :qrcodes

    resources :tipi_scuole, only: %i[index update]

    resources :propaganda, only: [:index]

    resources :giri do
      resource :planner, module: :giri, only: :show, controller: "planners"

      collection do
        get  'wizard',            to: 'giri/wizard#new',       as: 'wizard'
        get  'wizard/libri',      to: 'giri/wizard#libri',     as: 'wizard_libri'
        get  'wizard/scuole',     to: 'giri/wizard#scuole',    as: 'wizard_scuole'
        get  'wizard/riepilogo',  to: 'giri/wizard#riepilogo', as: 'wizard_riepilogo'
        post 'wizard',            to: 'giri/wizard#create',    as: 'create_wizard'
      end

      scope module: "giri/tappe" do
        resource :generazione, only: [:new, :create], controller: "generazione", path: "tappe/generazione", as: "tappe_generazione"
        resource :copia,       only: [:new, :create], controller: "copia",       path: "tappe/copia",       as: "tappe_copia"
        resource :svuotamento, only: :destroy,        controller: "svuotamento", path: "tappe/svuotamento", as: "tappe_svuotamento"
      end
    end

    resources :tappe do
      collection do
        get 'pianifica', to: 'tappe/pianifica#show'
      end
      resource :sort,    module: :tappe, only: :update, controller: "sorts"
      resource :rimando, module: :tappe, only: :create, controller: "rimandi"
      resources :bolle_visione, only: %i[new create]
      resources :tappa_giri, only: %i[new create index], controller: 'tappe/tappa_giri'
    end

    resources :collane do
      resources :collana_libri, only: %i[create destroy update]
    end

    resources :bolle_visione, only: %i[index show destroy] do
      member { post :rigenera }
      scope module: :bolle_visione do
        resources :righe,     only: %i[create update destroy]
        resources :documenti, only: :create
        resource  :persone,   only: %i[create update]
        resource  :rientro,   only: %i[create destroy]
      end
    end

    get 'profilo', to: 'profiles#get_user_profile'
    resources :access_tokens, only: %i[index show new create destroy], controller: 'access_tokens'
    resource :adozioni_analytics, only: [:show], controller: 'adozioni_analytics'
    # Nomi route espliciti (non dipendono dall'inflector: evita l'initializer uncountable)
    get 'controllo_adozioni', to: 'controllo_adozioni#index', as: :controllo_adozioni_index
    get 'controllo_adozioni/:codicescuola/anteprima', to: 'controllo_adozioni#anteprima', as: :controllo_adozioni_anteprima
    get 'controllo_adozioni/:codicescuola', to: 'controllo_adozioni#show', as: :controllo_adozioni
    scope module: "controllo_adozioni" do
      resource :promozione, only: %i[new create], controller: "promozioni",
               path: "controllo_adozioni/:codicescuola/promozione", as: :controllo_adozioni_promozione
      resource :promozioni_massive, only: :create, controller: "promozioni_massive",
               path: "controllo_adozioni/promozioni_massive", as: :controllo_adozioni_promozioni_massive
      resource :cambi_codice, only: :create, controller: "cambi_codice",
               path: "controllo_adozioni/cambi_codice", as: :controllo_adozioni_cambi_codice
      resource :scuole_nuove, only: :create, controller: "scuole_nuove",
               path: "controllo_adozioni/scuole_nuove", as: :controllo_adozioni_scuole_nuove
    end

    namespace :miur do
      resources :import_runs, only: %i[index show] do
        resource :reconcile, only: :create, module: :import_runs
      end
    end

    resources :profiles

    resources :stats do
      scope module: :stats do
        resource :execution, only: [:show]
        resource :position, only: [:update]
        resource :stato, only: [:update], controller: "stati"
      end
      # Legacy routes for compatibility
      member do
        get 'execute', to: 'stats/executions#show'
        patch :sort, to: 'stats/positions#update'
      end
    end

    get 'appunti/bozze', to: 'appunti/bozze#index', as: :bozze

    resources :appunti do
      resources :tappe
      scope module: :appunti do
        resource :goldness,  only: %i[create destroy]
        resource :closure,   only: %i[create destroy]
        resource :not_now,   only: %i[create destroy]
        resource :publication, only: %i[create destroy]
        resource :image, only: [:destroy]
        resources :attachments, only: [:destroy]
      end
      member do
        # Legacy routes for compatibility
        post 'publish', to: 'appunti/publications#create'
        delete 'remove_attachment', to: 'appunti/attachments#destroy'
        delete 'remove_image', to: 'appunti/images#destroy'
      end
    end

    resources :editori do
      resources :sconti, only: %i[index new create edit update destroy]
    end

    resources :categorie
    resources :sconti

    resources :user_scuole, only: %i[index destroy] do
      member do
        patch :sort
      end
    end

    resources :mappe, only: %i[show update] do
      collection do
        get 'calcola_percorso_ottimale'
      end
    end

    namespace :appunti do
      resource :prints, only: [:create]
      resource :bulk_tappe, only: [:create]
      resource :deletions, only: [:create]
    end

    namespace :tappe do
      resource :duplications, only: [:create]
      resource :bulk_updates, only: [:update]
      resource :deletions, only: [:create]
    end

    namespace :scuole do
      # Bulk actions for scuole
      resource :prints, only: [:create]
      resource :bulk_tappe, only: [:create]
    end

    resources :configurations, only: [] do
      get :ios_v1, on: :collection
      get :android_v1, on: :collection
    end

    get 'fornitori',      to: 'fornitori#index'
    get 'fornitori/:id',  to: 'fornitori#show', as: 'fornitore'

    resources :persone, only: %i[index show edit update create destroy] do
      resources :persona_classi, only: [:destroy], module: :persone
      resources :classe_chips, only: [:create], module: :persone, param: :combobox_value
      resources :saggi, only: %i[create update destroy], module: :persone
    end

    resources :scuole do
      get :email_pattern, on: :member
      resources :qrcodes
      resource :foglio_scuola, only: [:show], controller: 'scuole/foglio_scuola'
      resource :ritiro, only: :show, controller: 'ritiri' do
        scope module: :ritiri do
          resources :bolle, only: :create
          resources :righe, only: :update
        end
      end

      resources :saggi, only: %i[index create update destroy], controller: 'scuole/saggi' do
        post :genera_scarico, on: :collection
      end

      resource :scartata, only: %i[create destroy], controller: 'scuole/scartate'

      resources :disponibilita, only: %i[create destroy], controller: 'scuole/disponibilita'

      scope module: :scuole do
        resource :entries, only: [:show]
        resource :closed_entries, only: [:show]
        resource :adozioni, only: [:show], controller: 'adozioni'
        resource :persone_import, only: %i[new create], controller: 'persone_import'
        resources :persone_search, only: [:index], controller: 'persone_search'
        resource :cattedre, only: %i[show create destroy], controller: 'cattedre'
        resources :classe_chips, only: [:create], controller: 'classe_chips', param: :combobox_value
        resources :persone, only: %i[show create]
        resources :classi, only: %i[index show edit update create destroy] do
          member do
            post :import_adozioni
          end
          scope module: :classi do
            resource :entries, only: [:show]
            resource :closed_entries, only: [:show]
            resources :consegne_saggio, only: %i[create destroy]
            resources :persone, only: %i[new create destroy]
          end
        end
      end
    end
  end

  # =========================================
  # API
  # =========================================

  post  "api/mcp", to: "mcp#handle"
  match "api/mcp", to: "mcp#probe", via: [:get, :options]

  namespace :api do
    post 'whatsapp/contacts', to: 'whatsapp#create'

    # Non-versioned API endpoints
    resource :me, only: [:show], controller: 'me'
    namespace :stats do
      get :adozioni, to: 'adozioni#index'
      get :new_adozioni, to: 'new_adozioni#index'
    end

  end

  # =========================================
  # HEALTH CHECK E ROOT GLOBALE
  # =========================================

  get 'up' => 'rails/health#show', as: :rails_health_check

  # Root globale: redirect alla selezione account
  root 'accounts#index'
end
