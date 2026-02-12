# first, setup dashboard authentication
require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  # Letter opener web for viewing emails in development
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if defined?(LetterOpenerWeb)

  
  namespace :my do
    #resource :identity, only: :show
    #resources :access_tokens
    #resources :pins
    #resource :timezone
    resource :menu
  end
  
  
  # =========================================
  # AUTENTICAZIONE (senza contesto account)
  # =========================================

  # Passwordless authentication
  resources :magic_links, only: [:new, :create] do
    collection do
      get :sent
      get 'verify/:code', action: :verify, as: :verify
      post :select_account
    end
  end

  namespace :passwordless do
    resources :sessions, only: [:index, :destroy] do
      collection do
        delete :destroy_all
      end
    end
  end

  delete 'logout', to: 'passwordless/sessions#logout', as: :logout

  # =========================================
  # SELEZIONE ACCOUNT
  # =========================================

  resources :accounts, only: [:index, :new, :create]

  resources :users do
    scope module: :users do
      resource :personal_info
      resource :avatar
      resources :zone, only: [:index]
      resources :mandati, only: [:index]
    end
  end
  
  # =========================================
  # ADMIN ROUTES (con autenticazione admin)
  # =========================================

  constraints ->(request) {
    token = request.cookie_jar.signed[:session_token]
    session = Session.active.find_by(token: token) if token.present?
    session&.user&.admin?
  } do
    mount Blazer::Engine, at: 'blazer' if defined?(Blazer)
    mount RailsPerformance::Engine, at: 'rails/performance' if defined?(RailsPerformance)
    mount Sidekiq::Web => '/sidekiq'
    mount Motor::Admin => '/motor' if defined?(Motor)
    mount RailsDesigner::Engine, at: '/rails_designer' if defined?(RailsDesigner)
  end

  # =========================================
  # ROUTES CON CONTESTO ACCOUNT
  # =========================================

  scope "/:account_id", constraints: { account_id: /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/ } do
    # Dashboard account
    root "dashboard#index", as: :account_root

    # =========================================
    # TRIAGE SYSTEM
    # =========================================

    # Unified triage dashboard
    get "dashboard", to: "dashboard#index"

    # Dashboard columns (for lazy loading with pagination)
    namespace :dashboard do
      namespace :columns do
        resource :postponed, only: :show
        resource :closed, only: :show
      end
      resources :columns, only: :show
    end

    # Entries (unified triage items)
    resources :entries, only: [:index, :show] do
      scope module: :entries do
        resource :triage,    only: [:create, :destroy]
        resource :goldness,  only: [:create, :destroy]
        resource :closure,   only: [:create, :destroy]
        resource :not_now,   only: [:create, :destroy]
      end
    end

    # Columns (triage phases)
    resources :columns do
      resource :left_position, only: :create, module: :columns
      resource :right_position, only: :create, module: :columns
    end

    # Filtri salvati
    resources :filters, only: [:create, :destroy]

    namespace :filters do
      resource :settings_refresh, only: :create
    end

    # Dati aziendali (singular resource - one per account)
    resources :aziende

    # Chats
    resources :chats do
      resources :messages, only: [:create]
    end

    resources :models, only: [:index, :show] do
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
    get 'agenda', to: 'agenda#index'
    get 'agenda/:giorno', to: 'agenda#show', as: 'giorno'
    get 'agenda/:giorno/mappa', to: 'agenda#mappa', as: 'mappa_del_giorno'
    get 'agenda/:giorno/slideover', to: 'agenda#slideover', as: 'slideover'
    get 'agenda/:giorno/adozioni_tappe.pdf', to: 'agenda#adozioni_tappe_pdf', as: 'adozioni_tappe_pdf'
    get 'agenda/:giorno/tappe_giorno.pdf', to: 'agenda#tappe_giorno_pdf', as: 'tappe_giorno_pdf'
    get 'agenda/:giorno/dettaglio_appunti_documenti.pdf', to: 'agenda#dettaglio_appunti_documenti_pdf', as: 'dettaglio_appunti_documenti_pdf'
    get 'agenda/:giorno/fogli_scuola_tappe.pdf', to: 'agenda#fogli_scuola_tappe_pdf', as: 'fogli_scuola_tappe_pdf'

    get 'ordini_in_corso', to: 'ordini#index'
    
    # get 'search', to: 'search#index'
    # namespace :searches do
    #   get 'clientable/show'
    #   get 'clientable/new'
    #   resources :clientable, only: :index
    # end

    resource :search, only: [:show], controller: "search"

    # Ricerca unificata destinatari per combobox appunti
    resources :destinatari, only: [:index]


    post 'sfascicola', to: 'sfascicolator#generate'

    resources :clienti do
      scope module: :clienti do
        resource :closed_entries, only: [:show]
      end
      resources :sconti, only: [:index, :new, :create, :edit, :update, :destroy]
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
      resource :bulk_gestione, only: [:show], controller: "bulk_gestione"
      resource :bulk_consegne, only: [:create, :destroy]
      resource :bulk_pagamenti, only: [:create, :destroy]
      resource :bulk_derivazioni, only: [:create], controller: "bulk_derivazioni"
      resource :bulk_stati, only: [:create], controller: "bulk_stati"
    end

    resources :documenti do
      resources :documento_righe, only: [:new, :create], controller: "documento_righe"
      scope module: :documenti do
        resources :righe, only: [:create]
        resource :export, only: [:show]
        resource :status, only: [:edit, :update]
        resource :consegna, only: [:create, :update, :destroy], controller: "consegna"
        resource :pagamento, only: [:create, :update, :destroy], controller: "pagamento"
        resource :derivazione, only: [:create, :destroy], controller: "derivazione"
        resource :collegamento, only: [:create], controller: "collegamento"
      end
      collection do
        get "filtra"
        get "vendite"
      end
      member do
        # Legacy routes for compatibility
        get :esporta_xml, to: "documenti/exports#show"
        get :edit_status, to: "documenti/statuses#edit"
        patch :update_righe, to: "documenti/righe#create"
      end
    end

    # Singular resource for next documento number
    resource :documento_numero, only: [:show], controller: "documenti/numeri"

    resources :causali

    resources :campionario, only: [:show] do
      member do
        post :genera_saggi
        post :genera_saggi_50
      end
    end

    resources :documento_righe, only: %i[new show edit update destroy] do
      member do
        patch 'update_posizione'
      end
    end

    resources :libri_importer, only: [:new, :create, :show] do
      collection do
        post 'import_ministeriali'
        post 'import_confezioni'
        get 'export_confezioni'
      end
    end

    resource :clienti_importer, only: [:show, :create], controller: 'clienti_importer'

    resources :documenti_importer, only: [:new, :create, :show]

    # New unified imports controller (CRUD)
    resources :imports, only: [:index, :new, :create, :show]

    get 'classi', to: 'classi#index'
    get 'classi/:id', to: 'classi#show', as: 'classe'

    resources :classe_chips, only: :create, param: :combobox_value
    resources :libro_chips,  only: :create, param: :combobox_value
    resources :giro_chips, only: :create, param: :combobox_value

    resources :libri do
      collection do
        get 'crosstab'
        get 'scarico_fascicoli'
      end
      member do
        get 'get_prezzo_e_sconto'
        get 'fascicoli', to: 'confezionator#index'
        post 'fascicoli', to: 'confezionator#create', as: 'confezione'
        delete 'fascicoli', to: 'confezionator#destroy'
      end
      resources :qrcodes
    end

    namespace :libri do
      resource :prints, only: [:create]
      resource :deletions, only: [:create]
      resource :carrello, only: [:create, :update]
      resource :confezioni, only: [:create]
      resource :bulk_updates, only: [:update]
    end

    resources :qrcodes

    resources :confezione do
      member do
        patch 'sort', to: 'confezionator#sort'
      end
    end

    resources :tipi_scuole, only: %i[index update]

    resources :giri do
      resources :tappe, only: [:index]
      member do
        post 'bulk_create_tappe', to: 'tappe/giro_bulk_actions#create'
        delete 'remove_tappa/:tappa_id', to: 'tappe/giro_bulk_actions#remove_tappa', as: 'remove_tappa'
        post 'exclude_school/:school_id', to: 'giri#exclude_school', as: 'exclude_school'
        post 'include_school/:school_id', to: 'giri#include_school', as: 'include_school'
      end
    end

    resources :tappe do
      member do
        patch 'sort'
      end
    end

    get 'profilo', to: 'profiles#get_user_profile'
    resource :configurazione, only: [:show], controller: "configurazione"

    resources :profiles

    resources :stats do
      scope module: :stats do
        resource :execution, only: [:show]
        resource :position, only: [:update]
      end
      # Legacy routes for compatibility
      member do
        get "execute", to: "stats/executions#show"
        patch :sort, to: "stats/positions#update"
      end
    end

    resources :appunti do
      resources :tappe
      scope module: :appunti do
        resource :goldness,  only: [:create, :destroy]
        resource :closure,   only: [:create, :destroy]
        resource :not_now,   only: [:create, :destroy]
        resource :publication, only: [:create, :destroy]
        resource :image, only: [:destroy]
        resources :attachments, only: [:destroy]
      end
      member do
        # Legacy routes for compatibility
        post "publish", to: "appunti/publications#create"
        delete "remove_attachment", to: "appunti/attachments#destroy"
        delete "remove_image", to: "appunti/images#destroy"
      end
    end

    resources :zone, only: [:index] do
      collection do
        get 'select_zone'
        post 'assegna_scuole'
        post 'importa_scuole'
        delete 'rimuovi_scuole'
      end
    end

    resources :editori do
      resources :sconti, only: [:index, :new, :create, :edit, :update, :destroy]
    end

    resources :mandati do
      collection do
        get 'select_editori'
        post 'aggiorna_mie_adozioni'
      end
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

    resources :adozioni_comunicate do
      collection do
        get :import
        post :import
        get :confronto
        post :aggiorna_corrispondenze
        get :export_excel
      end
    end

    resources :configurations, only: [] do
      get :ios_v1, on: :collection
      get :android_v1, on: :collection
    end

    get 'fornitori',      to: 'fornitori#index'
    get 'fornitori/id',   to: 'fornitori#show', as: 'fornitore'

    get 'duplicates', to: 'articoli#duplicates'
    get 'duplicates/:codice_articolo', to: 'articoli#update_descrizione', as: 'update_descrizione'

    get 'articoli', to: 'articoli#index'
    get 'articoli/:codice_articolo', to: 'articoli#show', as: 'articolo'

    resources :scuole do
      resources :qrcodes

      scope module: :scuole do
        resource :entries, only: [:show]
        resources :classi, only: [:index, :show, :create, :destroy] do
          member do
            post :import_adozioni
          end
          scope module: :classi do
            resource :entries, only: [:show]
            resource :closed_entries, only: [:show]
            resources :consegne_saggio, only: [:create, :destroy]
          end
        end
      end
    end
  end

  # =========================================
  # HEALTH CHECK E ROOT GLOBALE
  # =========================================

  get 'up' => 'rails/health#show', as: :rails_health_check

  # Root globale: redirect alla selezione account
  root "accounts#index"
end
