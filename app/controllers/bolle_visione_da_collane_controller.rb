class BolleVisioneDaCollaneController < ApplicationController
  before_action :set_scuola

  def create
    collana_ids = Array(params[:collana_ids]).reject(&:blank?)
    if collana_ids.empty?
      redirect_to scuola_ritiro_path(@scuola), alert: "Seleziona almeno una collana." and return
    end

    BollaVisione.transaction do
      collana_ids.each do |cid|
        collana = Current.account.collane.find(cid)
        bv = @scuola.bolle_visione.create!(
          collana: collana,
          data_bolla: Date.current,
          user: Current.user,
          account: Current.account,
          note: "Bolla creata in fase di ritiro"
        )
        bv.crea_righe_da_collana!
      end
    end

    redirect_to scuola_ritiro_path(@scuola),
                notice: "#{collana_ids.size} bolle create."
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end
end
