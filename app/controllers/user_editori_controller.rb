
class UserEditoriController < ApplicationController
    
    before_action :require_signin
    
    # non funziona la form destroy passa il params[:id] e non params[:editore_id] 
    #before_action :set_user_editore, only: %i[    destroy ]

       
    def create

      @user_editore = UserEditore.new(user_id: params[:user_id], editore_id: params[:editore_id])
        
      respond_to do |format|
        if @user_editore.save
          
          format.turbo_stream 
          
          format.html { redirect_to user_url(current_user), notice: "Editore assegnato!" }
          #format.json { render :show, status: :created, location: @user_editore }
        else
          format.html { render :new, status: :unprocessable_entity }
          #format.json { render json: @user_editore.errors, status: :unprocessable_entity }
        end
      end
    end
  
    def destroy 

      # devo controllare il params[:id] e non params[:editore_id]
      @user_editore = UserEditore.find(user_editore_params)
      @user_editore.destroy!
  
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to user_url, notice: "Editore eliminato." }
        #format.json { head :no_content }
      end
    end
  
    private

      def set_user_editori
        @user_editore = UserEditore.find([params[:user_id], params[:editore_id]])
      end
  
      def user_editore_params
        params.require(:user_editore).permit(:editore_id, :user_id, :editore, :user)
      end
  
  end
  
