# first, setup dashboard authentication
require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  # Letter opener web for viewing emails in development
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if defined?(LetterOpenerWeb)

  
  namespace :my do
    resource :menu
  end
  
  
  # =========================================
  # AUTENTICAZIONE (senza contesto account)
  # =========================================

  # Passwordless authentication
  resources :magic_links, only: [:new, :create] do
    collection do
      get :sent
      post :authenticate
      get 'verify/:code', action: :verify, as: :verify
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

    namespace :admin do
      root "dashboard#index"
      resources :extension_mails, only: [:index, :create]
    end
  end

  # Download estensione Chrome (link pubblico per email)
  get "download/extension", to: "downloads#extension", as: :download_extension

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

    # Bulk actions per entries
    namespace :entries do
      resource :prints, only: [:create]
      resource :bulk_gestione, only: [:show], controller: "bulk_gestione"
      resource :bulk_stati, only: [:create], controller: "bulk_stati"
      resource :deletions, only: [:create]
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

    # =========================================
    # GESTIONE ACCOUNT (namespace accounts)
    # =========================================
    namespace :accounts, path: "" do
      resource :configurazione, only: [:show], controller: "configurazione"
      resource :azienda, only: [:show, :new, :create, :edit, :update]

      resources :zone, only: [:index, :new, :create, :destroy] do
        collection do
          resource :importazione, only: [:create], controller: "zone/importazioni"
        end
      end

      resources :mandati, only: [:index, :new, :create, :update, :destroy] do
        resource :disdetta, only: [:create, :destroy], module: :mandati
      end

      namespace :mandati do
        resources :gruppi, only: [:destroy], param: :id do
          resource :disdetta, only: [:create, :destroy], module: :gruppi
        end
        resource :sincronizzazione_adozioni, only: [:create]
      end

      resources :members, only: [:create, :update, :destroy] do
        scope module: :members do
          resources :scuole, only: [:create, :destroy], controller: "membership_scuole"
          resource :bulk_scuole, only: [:create, :destroy], controller: "bulk_membership_scuole"
        end
      end

      resource :distribuzione, only: [:show], controller: "distribuzione" do
        resource :assegnazione, only: [:create], controller: "distribuzione/assegnazioni"
      end

      resources :aree, only: [:show], param: :provincia do
        resource :assegnazione, only: [:create], controller: "aree/assegnazioni"
        resources :mandati, only: [:create, :destroy], controller: "aree/mandati", param: :gruppo
      end
    end

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
    get 'agenda/planner', to: 'agenda#planner', as: 'agenda_planner'
    get 'agenda', to: 'agenda#index'
    get 'agenda/:giorno', to: 'agenda#show', as: 'giorno'
    get 'agenda/:giorno/mappa', to: 'agenda#mappa', as: 'mappa_del_giorno'
    get 'agenda/:giorno/adozioni_tappe.pdf', to: 'agenda#adozioni_tappe_pdf', as: 'adozioni_tappe_pdf'
    get 'agenda/:giorno/tappe_giorno.pdf', to: 'agenda#tappe_giorno_pdf', as: 'tappe_giorno_pdf'
    get 'agenda/:giorno/dettaglio_appunti_documenti.pdf', to: 'agenda#dettaglio_appunti_documenti_pdf', as: 'dettaglio_appunti_documenti_pdf'
    get 'agenda/:giorno/fogli_scuola_tappe.pdf', to: 'agenda#fogli_scuola_tappe_pdf', as: 'fogli_scuola_tappe_pdf'

    resource :search, only: [:show], controller: "search"

    # Ricerca unificata destinatari per combobox appunti
    resources :destinatari, only: [:index]

    post 'sfascicola', to: 'sfascicolator#generate'

    resources :clienti do
      scope module: :clienti do
        resource :entries, only: [:show]
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

    resources :titoli, only: [:show], param: :codice_isbn

    resources :libri_importer, only: [:new, :create, :show] do
      collection do
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
      resource :movimenti, only: [:show], module: :libri
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
      member do
        get 'planner'
        get 'copia'
      end

      get  'genera_tappe', to: 'giri/tappe#new', as: 'genera_tappe'
      post 'genera_tappe', to: 'giri/tappe#create'
      post 'copia_tappe', to: 'giri/tappe#copy', as: 'copia_tappe'
      delete 'svuota_tappe', to: 'giri/tappe#destroy_all', as: 'svuota_tappe'
    end

    resources :tappe do
      member do
        patch 'sort'
      end
      resources :bolle_visione, only: [:new, :create]
    end

    resources :collane do
      resources :collana_libri, only: [:create, :destroy, :update]
    end

    resources :bolle_visione, only: [:index, :show] do
      resources :bolla_visione_righe, only: [:update, :destroy]
      resources :persone, only: [:create], module: :bolle_visione
    end

    get 'profilo', to: 'profiles#get_user_profile'
    resources :access_tokens, only: [:index, :show, :new, :create, :destroy], controller: "access_tokens"
    resource :adozioni_analytics, only: [:show], controller: "adozioni_analytics"

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

    resources :editori do
      resources :sconti, only: [:index, :new, :create, :edit, :update, :destroy]
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

    resources :persone, only: [:show]

    resources :scuole do
      resources :qrcodes
      resource :foglio_scuola, only: [:show], controller: "scuole/foglio_scuola"

      resources :saggi, only: [:index, :create, :update, :destroy], controller: "scuole/saggi" do
        post :genera_scarico, on: :collection
      end

      scope module: :scuole do
        resource :entries, only: [:show]
        resource :closed_entries, only: [:show]
        resource :adozioni, only: [:show], controller: "adozioni"
        resource :persone_import, only: [:new, :create], controller: "persone_import"
        resource :cattedre, only: [:show, :create, :destroy], controller: "cattedre"
        resources :persone, only: [:show, :edit, :update, :create] do
          resources :persona_classi, only: [:destroy], module: :persone
          resources :classe_chips, only: [:create], module: :persone, param: :combobox_value
          resources :saggi, only: [:create, :update, :destroy], module: :persone
        end
        resources :classi, only: [:index, :show, :edit, :update, :create, :destroy] do
          member do
            post :import_adozioni
          end
          scope module: :classi do
            resource :entries, only: [:show]
            resource :closed_entries, only: [:show]
            resources :consegne_saggio, only: [:create, :destroy]
            resources :persone, only: [:new, :create, :destroy]
          end
        end
      end
    end
  end

  # =========================================
  # API
  # =========================================

  namespace :api do
    post "whatsapp/contacts", to: "whatsapp#create"
  end

  # =========================================
  # HEALTH CHECK E ROOT GLOBALE
  # =========================================

  get 'up' => 'rails/health#show', as: :rails_health_check

  # Root globale: redirect alla selezione account
  root "accounts#index"
end
