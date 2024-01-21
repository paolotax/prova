class MandatiController < ApplicationController
    
    before_action :require_signin
    
    # non funziona la form destroy passa il params[:id] e non params[:editore_id] 
    #before_action :set_mandato, only: %i[    destroy ]

       
    def create     
      begin
        @mandato = Mandato.new(user_id: params[:user_id], editore_id: params[:editore_id])        
        @mandato.save!
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
  
  end
  
