class PagesController < ApplicationController

  def index
    
    if current_user
      @chat = Chat.last ||= Chat.create(user_id: current_user.id) if current_user.admin?
    else
      redis = Redis.new
      redis.incr "page_hits"
      @page_hits = redis.get "page_hits"
      #@page_hits = 2345  
      
      # Cache delle statistiche adozioni (cache di 1 mese)
      @totale_scuole = Rails.cache.fetch("stats/totale_scuole", expires_in: 1.month) do
        ImportAdozione.distinct.count(:CODICESCUOLA)
      end
      
      @old_totale_scuole = Rails.cache.fetch("stats/old_totale_scuole", expires_in: 1.month) do
        OldAdozione.distinct.count(:codicescuola)
      end
      
      @totale_adozioni = Rails.cache.fetch("stats/totale_adozioni", expires_in: 1.month) do
        ImportAdozione.count
      end
      
      @old_totale_adozioni = Rails.cache.fetch("stats/old_totale_adozioni", expires_in: 1.month) do
        OldAdozione.count
      end
    end          
  end

end
