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


    def oggi
        
        @scuole = current_user.import_scuole
                    .includes(:appunti_da_completare)
                    .where(id: current_user.tappe.di_oggi.where(tappable_type: "ImportScuola").pluck(:tappable_id))
        
        @clienti = current_user.clienti
                    .where(id: current_user.tappe.di_oggi.where(tappable_type: "Cliente").pluck(:tappable_id))
        
        
        @tappe = current_user.tappe.di_oggi.includes(:tappable, :giro).order(:position)
       
        # @grouped_records = @tappe.group_by{|t| t.tappable.direzione_or_privata }
        # 
        @appunti_di_oggi = current_user.appunti.da_completare.nel_baule_di_oggi
                                    .with_attached_attachments
                                    .with_attached_image
                                    .with_rich_text_content
                                    .includes(:import_scuola)
               
        # @appunti_di_oggi = current_user.appunti.non_archiviati.nel_baule_di_oggi.group_by{ |a| a.import_scuola.id }
        
        # @adozioni_di_oggi = current_user.mie_adozioni.nel_baule_di_oggi
        # # fix this @adozioni in form_multi 
        # @adozioni = current_user.adozioni.vendita.joins(:scuola).where("import_scuole.id in (?)", @scuole_di_oggi.pluck(:id))

        # @indirizzi = current_user.import_scuole.where(id: current_user.tappe.di_oggi.pluck(:tappable_id))

        respond_to do |format|
          format.html
          format.xlsx
        end
    end
end
