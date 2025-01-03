# first, setup dashboard authentication
require "sidekiq/web"

# Sidekiq::Web.use Rack::Auth::Basic do |username, password|
#   username == "admin" && password == "password"
# end

# then mount it
Rails.application.routes.draw do

  resources :voice_notes, only: [:create, :index, :destroy] do
    member do
      post :transcribe
      post :create_note_from_transcript
    end
  end
  
  get "agenda", to: "agenda#index"
  get "agenda/:giorno", to: "agenda#show", as: "giorno"
  get "agenda/:giorno/mappa", to: "agenda#mappa", as: "mappa_del_giorno"

  authenticate :user, ->(user) { user.admin? } do
    mount Blazer::Engine, at: "blazer"
    mount RailsPerformance::Engine, at: 'rails/performance'
    mount Sidekiq::Web => "/sidekiq"
    mount Avo::Engine, at: Avo.configuration.root_path
    mount RailsDesigner::Engine, at: '/rails_designer'
  end

  resources :chats, only: %i[create show new] do
    resources :messages, only: %i[create]
  end

  devise_for :users, controllers: { confirmations: 'confirmations', registrations: 'users/registrations' }
  
  get 'ordini_in_corso', to: "ordini#index"
  get "cerca", to: "search#index"
  
  namespace :searches do
    get 'clientable/show'
    get 'clientable/new'
  end

  post "sfascicola", to: "sfascicolator#generate"

  resources :clienti do
    collection do
      get 'filtra'
    end
  end
  
  resources :documenti do 
    resources :steps, only: [:show, :update], controller: 'steps_controllers/documento_steps'
    collection do
      get 'filtra' 
      get 'nuovo_numero_documento'
    end
  end

  resources :causali
  
  resources :documento_righe, only: [:new, :destroy] do
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
  
  #get "vendite", to: "adozioni#index"
  resources :adozioni do 
    collection do
      post 'bulk_create'
      put 'bulk_update', format: "pdf"
      get "riepilogo"
    end
  end
    
  resources :libri do
    collection do
      get 'filtra'
      get 'crosstab'
      get 'scarico_fascicoli'
    end
    member do
      get 'get_prezzo_copertina_cents'
      get "fascicoli", to: "confezionator#index"
      post 'fascicoli', to: "confezionator#create", as: "confezione"
      delete 'fascicoli', to: "confezionator#destroy"
    end
  end

  resources :confezione do
    member do
      patch 'sort', to: "confezionator#sort"
    end
  end

  resources :tipi_scuole, only: [:index, :update]
    
  resources :giri do 
    member do 
      get "tappe"
      post 'crea_tappe'
    end
  end

  resources :tappe do
    collection do
      patch 'bulk_update'
    end
    member do
      post 'duplica'
      patch 'sort'
    end
  end
 
  resources :profiles do
    resources :steps, only: [:show, :update], controller: 'steps_controllers/profile_steps'
  end
  
  resources :users, only: [:index, :show] do    
    member do
      post  'modifica_navigatore' 
    end
  end
    
  resources :stats do
    member do
      get 'execute'
    end
  end
  
  resources :appunti do
    resources :tappe
    collection do
      get "filtra"
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
  
  resources :editori
  
  resources :mandati do
    collection do
      get 'select_editori'
    end
  end
  
  resources :user_scuole, only: [:index, :destroy]
  
  resources :import_scuole do
    resources :tappe
    collection do
      get 'filtra'
      get 'appunti'
    end
    member do
      get 'classi_che_adottano'
      get 'combobox_classi'
    end
  end

  resources :mappe, only: [:show, :update] do
    collection do
      get 'calcola_percorso_ottimale'
    end
  end
  
  namespace :import_scuole do
    resources :bulk_actions, only: [] do
      collection do
        patch :add_tappa_oggi
        patch :add_tappa_domani
        patch :add_tappa_custom
      end
    end
  end


  # resources :import_scuole, except: :show
  # get 'import_scuole/:CODICESCUOLA', to: 'import_scuole#show'
  
  resources :import_adozioni, only: [:index, :show] do
    collection do
      get "filtra"
      put 'bulk_update', format: "pdf"
    end
  end

  # get 'clienti',      to: 'clienti#index'
  # get 'clienti/:id',  to: 'clienti#show', as: 'cliente'
 
  get 'fornitori',      to: 'fornitori#index'
  get 'fornitori/id',   to: 'fornitori#show', as: 'fornitore'
  

  get 'duplicates',   to: 'articoli#duplicates'
  
  get "duplicates/:codice_articolo", to: "articoli#update_descrizione", as: "update_descrizione"


  get 'articoli',     to: 'articoli#index'
  get 'articoli/:codice_articolo', to: 'articoli#show', as: 'articolo'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "pages#index"
end
