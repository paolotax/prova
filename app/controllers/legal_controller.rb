class LegalController < ApplicationController
  layout "public"

  skip_before_action :authenticate_user!

  def privacy
    @page_title = "Informativa sulla privacy"
  end

  def data_sources
    @page_title = "Fonti e licenze dei dati"
  end
end
