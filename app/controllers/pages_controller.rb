class PagesController < ApplicationController

    def index 
        redis = Redis.new
        redis.incr "page_hits"
        @page_hits = redis.get "page_hits"
        #@page_hits = 2345
        @totale_scuole = NewScuola.count
        @old_totale_scuole = ImportScuola.count
        @totale_adozioni = NewAdozione.count 
        @old_totale_adozioni = ImportAdozione.count

        if current_user && current_user.admin?
          @chat = Chat.last ||= Chat.create(user_id: current_user.id)
        end
    end

end
