class MandatiController < ApplicationController
    
    before_action :require_signin
    
    #before_action :set_mandato, only: %i[    destroy ]
    before_action :find_editore

    def index
      @gruppi = Editore.order(:gruppo)
                     .select(:gruppo).distinct || []
      
      @editori = Editore.where(gruppo: @gruppo&.gruppo)
                      .order(:editore)
                      .select(:id, :editore).distinct || []  
      #fail
    end
        
    def create     
      begin

        if !params[:heditore].blank?
          editore_id = params[:heditore].to_i         
        end

        @mandato = current_user.mandati.new(editore_id: editore_id)  
        @mandato.save!        
        raise @mandato.errors.full_messages unless @mandato.errors.empty?
      rescue ActiveRecord::RecordNotUnique
        flash[:error] = "Violazione chiave!!"
        @mandato.reload
      end

      respond_to do |format|           
        format.turbo_stream             
        format.html { redirect_to user_url(current_user), notice: "Editore assegnato!" }
        #format.json { render :show, status: :created, location: @mandato }
      end   
    end
  
    def destroy 

      id = params.extract_value(:id)
      @mandato = Mandato.find(id)
      @mandato.destroy!
  
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to user_url, notice: "Editore eliminato." }
        #format.json { head :no_content }
      end
    end
  
    private

      def set_user_editori
        @mandato = Mandato.find([params[:user_id], params[:editore_id]])
      end
  
      def mandato_params
        params.require(:mandato).permit(:editore_id, :user_id)
      end

  
      def find_editore
        @gruppo   = Editore.where(gruppo: params[:gruppo].presence).first
        @editore  = Editore.where(id: params[:id].presence).first
      end
  
  end
  
