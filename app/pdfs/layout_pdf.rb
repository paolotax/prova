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
      text "Agente di Zona - #{"PAOLO TASSINARI"}", :size => 11, :align => :right
      text "Via Saragat, 7",  :align => :right
      text "42124 Reggio Emilia RE",   :align => :right
      move_down 5
      #text "tel 051 6342585  fax 051 6341521", :align => :right
      text "cell #{"347 2371680"}", :align => :right
      text "email #{"paolo.tassinari@hey.com"}", :align => :right
      move_down 5
    end
  end
end