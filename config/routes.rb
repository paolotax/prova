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

  # =========================================
  # USER SETTINGS (senza contesto account)
  # =========================================

  resource :personal_info, only: [:show, :new, :create, :edit, :update]
  resource :avatar, only: [:show, :edit, :update, :destroy]

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
    mount Avo::Engine, at: Avo.configuration.root_path if defined?(Avo)
    mount RailsDesigner::Engine, at: '/rails_designer' if defined?(RailsDesigner)
  end

  # =========================================
  # ROUTES CON CONTESTO ACCOUNT
  # =========================================

  scope "/:account_id" do
    # Dashboard account
    root "pages#index", as: :account_root

    # Dati aziendali (singular resource - one per account)
    resource :azienda, only: [:show, :new, :create, :edit, :update]

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
    get 'cerca', to: 'search#index'

    namespace :searches do
      get 'clientable/show'
      get 'clientable/new'
      resources :clientable, only: :index
    end

    post 'sfascicola', to: 'sfascicolator#generate'

    resources :clienti do
      resources :sconti, only: [:index, :new, :create, :edit, :update, :destroy]
      collection do
        get 'filtra'
      end
    end

    resources :documenti do
      resources :steps, only: %i[show update], controller: 'steps_controllers/documento_steps'
      collection do
        get 'filtra'
        get 'nuovo_numero_documento'
        get 'vendite'
      end
      member do
        get :esporta_xml
        get :edit_status
      end
    end

    resources :causali

    resources :campionario, only: [:show] do
      member do
        post :genera_saggi
        post :genera_saggi_50
      end
    end

    resources :documento_righe, only: %i[new destroy] do
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

    resources :clienti_importer, only: [:new, :create, :show]

    resources :documenti_importer, only: [:new, :create, :show]

    get 'classi', to: 'classi#index'
    get 'classi/:id', to: 'classi#show', as: 'classe'

    resources :classe_chips, only: :create, param: :combobox_value
    resources :libro_chips,  only: :create, param: :combobox_value
    resources :giro_chips, only: :create, param: :combobox_value

    resources :adozioni do
      collection do
        post 'bulk_create'
        put 'bulk_update', format: 'pdf'
        get 'riepilogo'
      end
    end

    resources :libri do
      collection do
        get 'filtra'
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
      resources :bulk_actions, only: [] do
        post :carrello, on: :collection
        post :aggiungi, on: :collection
      end
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

    resources :profiles do
      resources :steps, only: %i[show update], controller: 'steps_controllers/profile_steps'
    end

    resources :users, only: %i[index show] do
      member do
        post  'modifica_navigatore'
      end
    end

    resources :stats do
      member do
        get 'execute'
        patch :sort
      end
    end

    resources :appunti do
      resources :tappe
      collection do
        get 'filtra'
        get 'archiviati'
        get 'saggi'
      end
      member do
        put 'modifica_stato'
        delete 'remove_attachment'
        delete 'remove_image'
      end
    end

    resources :zone, only: [:index] do
      collection do
        get 'select_zone'
        post 'assegna_scuole'
        delete 'rimuovi_scuole'
      end
    end

    resources :editori do
      resources :sconti, only: [:index, :new, :create, :edit, :update, :destroy]
    end

    resources :mandati do
      collection do
        get 'select_editori'
      end
    end

    resources :categorie
    resources :sconti

    resources :user_scuole, only: %i[index destroy] do
      member do
        patch :sort
      end
    end

    resources :import_scuole do
      resources :tappe
      resources :sconti, only: [:index, :new, :create, :edit, :update, :destroy]
      collection do
        get 'filtra'
        get 'appunti'
      end
      member do
        get 'classi_che_adottano'
        get 'combobox_classi'
      end
    end

    resources :mappe, only: %i[show update] do
      collection do
        get 'calcola_percorso_ottimale'
      end
    end

    namespace :import_scuole do
      resources :bulk_actions, only: [] do
        collection do
          patch :print_all, format: 'pdf'
          patch :create_tappa
        end
      end
    end

    namespace :appunti do
      resources :bulk_actions, only: [] do
        collection do
          patch :print_all, format: 'pdf'
          patch :create_tappa
          patch :segna_come
          delete :destroy_all
        end
      end
    end

    namespace :tappe do
      resources :bulk_actions do
        patch :duplica, on: :collection
        patch :update_all, on: :collection
        delete :destroy_all, on: :collection
      end
    end

    namespace :documenti do
      resources :bulk_actions, only: [] do
        collection do
          patch :print_all
          post :duplica
          post :unisci
          delete :destroy_all
          patch :update_stato
        end
      end
    end

    resources :import_adozioni, only: %i[index show] do
      collection do
        get 'filtra'
      end
    end

    namespace :import_adozioni do
      resources :bulk_actions, only: [] do
        collection do
          patch :print_all, format: 'pdf'
        end
      end
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
    end
  end

  # =========================================
  # HEALTH CHECK E ROOT GLOBALE
  # =========================================

  get 'up' => 'rails/health#show', as: :rails_health_check

  # Root globale: redirect alla selezione account
  root "accounts#index"
end
