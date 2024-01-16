Rails.application.routes.draw do
  resources :editori
  
  resources :users do 
    member do 
      post 'assegna_scuole'
    end
  end

  get "signup" => "users#new"

  resource :session, only: [:new, :create, :destroy]
  get "signin" => "sessions#new"
  
  resources :user_scuole
  
  resources :import_scuole
  # resources :import_scuole, except: :show
  # get 'import_scuole/:CODICESCUOLA', to: 'import_scuole#show'
  
  
  resources :import_adozioni
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
