class PagesController < ApplicationController

    def index 
        redis = Redis.new
        redis.incr "page_hits"
        @page_hits = redis.get "page_hits"
        #@page_hits = 2345
        @totale_scuole = ImportScuola.count
        @totale_adozioni = ImportAdozione.count

    end


    def oggi
        @tappe = current_user.tappe.di_oggi
        
        @grouped_records = @tappe.group_by{|t| t.tappable.direzione_or_privata }
        
        @scuole_di_oggi = current_user.import_scuole.where(id: @tappe.where(tappable_type: "ImportScuola").pluck(:tappable_id)) 
        
        @appunti_di_oggi = current_user.appunti.nel_baule_di_oggi
        
        @adozioni_di_oggi = current_user.mie_adozioni.nel_baule_di_oggi
    end
end
