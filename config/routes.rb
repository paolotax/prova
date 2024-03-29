# == Route Map
#

# first, setup dashboard authentication
require "sidekiq/web"
Sidekiq::Web.use Rack::Auth::Basic do |username, password|
  username == "admin" && password == "password"
end

# then mount it
Rails.application.routes.draw do
  
  resources :tipi_scuole, only: [:index, :edit, :update]
  
  mount Sidekiq::Web => "/sidekiq"

  devise_for :users, controllers: { confirmations: 'confirmations' }

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
      get 'appunti'
    end
  end

  # resources :import_scuole, except: :show
  # get 'import_scuole/:CODICESCUOLA', to: 'import_scuole#show'
  
  resources :import_adozioni do 
    resources :tappe
  end

  get 'clienti',      to: 'clienti#index'
  get 'clienti/:id',  to: 'clienti#show', as: 'cliente'
 
  get 'fornitori',      to: 'fornitori#index'
  get 'fornitori/id',   to: 'fornitori#show', as: 'fornitore'
  

  get 'duplicates',   to: 'articoli#duplicates'
  
  get "duplicates/:codice_articolo", to: "articoli#update_descrizione", as: "update_descrizione"


  get 'articoli',     to: 'articoli#index'
  get 'articoli/:codice_articolo', to: 'articoli#show', as: 'articolo'

  get 'documenti',     to: 'documenti#index'
  get 'documenti/:id', to: 'documenti#show', as: 'documento'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "pages#index"
end
