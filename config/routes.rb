# first, setup dashboard authentication
require 'sidekiq/web'
require 'sidekiq-scheduler/web'

# Sidekiq::Web.use Rack::Auth::Basic do |username, password|
#   username == "admin" && password == "password"
# end

# then mount it
Rails.application.routes.draw do
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

  get 'agenda', to: 'agenda#index'
  get 'agenda/:giorno', to: 'agenda#show', as: 'giorno'
  get 'agenda/:giorno/mappa', to: 'agenda#mappa', as: 'mappa_del_giorno'
  get 'agenda/:giorno/slideover', to: 'agenda#slideover', as: 'slideover'
  get 'agenda/:giorno/adozioni_tappe.pdf', to: 'agenda#adozioni_tappe_pdf', as: 'adozioni_tappe_pdf'
  get 'agenda/:giorno/tappe_giorno.pdf', to: 'agenda#tappe_giorno_pdf', as: 'tappe_giorno_pdf'
  get 'agenda/:giorno/dettaglio_appunti_documenti.pdf', to: 'agenda#dettaglio_appunti_documenti_pdf', as: 'dettaglio_appunti_documenti_pdf'
  get 'agenda/:giorno/fogli_scuola_tappe.pdf', to: 'agenda#fogli_scuola_tappe_pdf', as: 'fogli_scuola_tappe_pdf'

  authenticate :user, ->(user) { user.admin? } do
    mount Blazer::Engine, at: 'blazer'
    mount RailsPerformance::Engine, at: 'rails/performance'
    mount Sidekiq::Web => '/sidekiq'
    mount Avo::Engine, at: Avo.configuration.root_path
    mount RailsDesigner::Engine, at: '/rails_designer'
  end

  resources :chats, only: %i[create show new] do
    resources :messages, only: %i[create]
  end

  devise_for :users, controllers: { confirmations: 'confirmations', registrations: 'users/registrations' }

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
    end
  end

  resources :causali

  resources :documento_righe, only: %i[new destroy] do
    member do
      patch 'update_posizione'
    end
  end

  resources :libri_importer, only: [:create] do
    collection do
      post 'import_ministeriali'
    end
  end

  resources :clienti_importer, only: [:create] do
  end

  resources :documenti_importer, only: [:create]

  get 'classi', to: 'classi#index'
  get 'classi/:id', to: 'classi#show', as: 'classe'

  resources :classe_chips, only: :create, param: :combobox_value
  resources :libro_chips,  only: :create, param: :combobox_value
  resources :giro_chips, only: :create, param: :combobox_value

  # get "vendite", to: "adozioni#index"
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

  # resources :import_scuole, except: :show
  # get 'import_scuole/:CODICESCUOLA', to: 'import_scuole#show'

  resources :import_adozioni, only: %i[index show] do
    collection do
      get 'filtra'
      put 'bulk_update', format: 'pdf'
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

  # get 'clienti',      to: 'clienti#index'
  # get 'clienti/:id',  to: 'clienti#show', as: 'cliente'

  get 'fornitori',      to: 'fornitori#index'
  get 'fornitori/id',   to: 'fornitori#show', as: 'fornitore'

  get 'duplicates', to: 'articoli#duplicates'

  get 'duplicates/:codice_articolo', to: 'articoli#update_descrizione', as: 'update_descrizione'

  get 'articoli', to: 'articoli#index'
  get 'articoli/:codice_articolo', to: 'articoli#show', as: 'articolo'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  root 'pages#index'

  resources :scuole do
    resources :qrcodes
  end
end
