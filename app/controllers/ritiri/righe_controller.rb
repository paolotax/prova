class Ritiri::RigheController < Ritiri::BaseController
  def update
    riga = find_riga
    if params[:esito].present?
      riga.update!(esito: params[:esito], processato_at: Time.current)
    else
      riga.update!(esito: nil, processato_at: nil)
    end
    redirect_to redirect_target(riga)
  end

  private

  def find_riga
    Current.account.bolla_visione_righe
      .joins(:bolla_visione)
      .where(bolle_visione: { scuola_id: @scuola.id })
      .find(params[:id])
  end

  def redirect_target(riga)
    case params[:return_to]
    when "bolla" then bolla_visione_path(riga.bolla_visione)
    else scuola_ritiro_path(@scuola)
    end
  end
end
