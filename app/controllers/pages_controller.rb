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

        @indirizzi = @tappe.map do |t|
          {
            latitude: t.latitude,
            longitude: t.longitude
          }
        end

        @appunti_di_oggi = current_user.appunti.da_completare.nel_baule_di_oggi
                                    .with_attached_attachments
                                    .with_attached_image
                                    .with_rich_text_content
                                    .includes(:import_scuola)
                       
        respond_to do |format|
          format.html
          format.xlsx
        end
    end
end
