module LayoutPdf


  def logo
    # bounding_box([0, bounds.top], :width => bounds.width / 2.0, :height => 100) do
    #   giunti = "#{Rails.root}/public/images/giunti_scuola.jpg"
    #   image giunti, :width => 200, :height => 35, :at => [-10, bounds.top]
    # end
  end
  
  def agente(user)
    bounding_box([bounds.width / 2.0, bounds.top], :width => bounds.width / 2.0, :height => 100) do
      #stroke_bounds
      font_size 9
      text "Agente di Zona - #{user.profile_ragione_sociale}", :size => 11, :align => :right
      text user.profile_indirizzo,  :align => :right
      text "#{user.profile_cap} #{user.profile_citta}",   :align => :right
      move_down 5
      #text "tel 051 6342585  fax 051 6341521", :align => :right
      text "cell #{user.profile_cellulare}", :align => :right
      text "email #{user.profile_email}", :align => :right
      move_down 5
    end
  end
end