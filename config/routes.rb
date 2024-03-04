# == Route Map
#

# first, setup dashboard authentication
require "sidekiq/web"
Sidekiq::Web.use Rack::Auth::Basic do |username, password|
  username == "admin" && password == "password"
end

# then mount it
Rails.application.routes.draw do
  
  mount Sidekiq::Web => "/sidekiq"
  
  
  devise_for :users, controllers: { confirmations: 'confirmations' }

  resources :users, only: [:index, :show] do
    member do
      post  'modifica_navigatore' 
      post 'assegna_scuole'
      delete 'rimuovi_scuole'
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
  
  
  get "zone", to: 'zone#index'
  
  resources :editori
  
  resources :mandati



  # TOLTE PER DEVISE
  # get "signup" => "users#new"
  # resource :session, only: [:new, :create, :destroy]
  # get "signin" => "sessions#new"
  
  resources :user_scuole, only: [:index, :destroy]
  #get "users/:id/scuole" => "user_scuole#index", as: "user_scuole"  
  #delete  "user_scuole/:id", to: "user_scuole#destroy"
  
  resources :import_scuole do
    resources :tappe
    collection do
      get 'appunti'
    end
  end

  get 'tappe', to: 'tappe#index', as: 'tappa'
  
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
