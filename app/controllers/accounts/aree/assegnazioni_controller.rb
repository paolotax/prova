module Accounts
  module Aree
    class AssegnazioniController < ApplicationController
      def create
        scuola = Current.account.scuole.find(params[:scuola_id])
        area = params[:area].presence

        # Update the school's area
        scuola.update!(area: area)
        # Plessi are updated automatically via the after_update_commit callback

        redirect_to accounts_aree_path(provincia: params[:aree_provincia]), status: :see_other
      end
    end
  end
end
