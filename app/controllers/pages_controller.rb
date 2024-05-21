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
        @scuole_di_oggi = current_user.import_scuole.where(id: @current_user.tappe.di_oggi.where(tappable_type: "ImportScuola").pluck(:tappable_id)) 
        
        @tappe = current_user.tappe.where(tappable_id: @scuole_di_oggi.pluck(:id))
       
        @grouped_records = @tappe.group_by{|t| t.tappable.direzione_or_privata }
               
        @appunti_di_oggi = current_user.appunti.non_archiviati.nel_baule_di_oggi.group_by{ |a| a.import_scuola.id }
        
        @adozioni_di_oggi = current_user.mie_adozioni.nel_baule_di_oggi

        @vendite_di_oggi = current_user.adozioni.vendite.joins(:scuola).where("import_scuole.id in (?)", @scuole_di_oggi.pluck(:id))
    end
end
