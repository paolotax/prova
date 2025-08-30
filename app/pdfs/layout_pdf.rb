require 'prawn-svg'

module LayoutPdf

  def current_user
    @view.current_user
  end

  def logo(editore = nil)
    bounding_box([0, bounds.top], :width => bounds.width / 2.0, :height => 100) do
      if editore == "GAIA EDIZIONI"
        # Logo GAIA EDIZIONI
        begin
          gaia_png = "#{Rails.root}/app/assets/images/gaia.png"
          image gaia_png, :width => 200, :at => [-10, bounds.top]
        rescue => e
          Rails.logger.warn "Errore nel caricamento logo GAIA: #{e.message}"
          # Fallback testo se l'immagine non funziona
          text "GAIA EDIZIONI", :size => 16, :style => :bold, :at => [-10, bounds.top - 20]
        end
      else
        # Logo GIUNTI SCUOLA (default)
        begin
          giunti_svg = File.read("#{Rails.root}/app/assets/svg/giunti_scuola.svg")
          svg giunti_svg, :at => [-10, bounds.top], :width => 200
        rescue => e
          # Fallback all'immagine JPG se l'SVG non funziona
          Rails.logger.warn "Errore nel caricamento SVG: #{e.message}"
          giunti = "#{Rails.root}/public/images/giunti_scuola.jpg"
          image giunti, :width => 200, :height => 35, :at => [-10, bounds.top]
        end
      end
    end
  end  
  
  def intestazione(editore = nil)
    logo(editore)
    agente(current_user) unless current_user.nil?
  end
  
  def intestazione_ruotata(editore = nil)
    # Intestazione ruotata di 90 gradi per layout verticale
    rotate(90, origin: [0, 0]) do
      # Trasla per posizionare correttamente l'intestazione ruotata
      translate(0, -bounds.width) do
        # Logo ruotato
        logo_ruotato(editore)
        # Agente ruotato
        agente_ruotato(current_user) unless current_user.nil?
      end
    end
  end
  

  def logo_ruotato(editore = nil)
    # Logo ruotato di 90 gradi con posizionamento assoluto
    rotate(90, origin: [bounds.width / 2, bounds.height / 2]) do
      if editore == "GAIA EDIZIONI"
        # Logo GAIA EDIZIONI
        begin
          gaia_png = "#{Rails.root}/app/assets/images/gaia.png"
          image gaia_png, :width => 80, :at => [-40, -10]
        rescue => e
          Rails.logger.warn "Errore nel caricamento logo GAIA ruotato: #{e.message}"
          draw_text "GAIA EDIZIONI", :size => 10, :style => :bold, :at => [-30, 0]
        end
      else
        # Logo GIUNTI SCUOLA (default)
        begin
          giunti_svg = File.read("#{Rails.root}/app/assets/svg/giunti_scuola.svg")
          svg giunti_svg, :at => [-40, -10], :width => 80
        rescue => e
          Rails.logger.warn "Errore nel caricamento SVG ruotato: #{e.message}"
          begin
            giunti = "#{Rails.root}/public/images/giunti_scuola.jpg"
            image giunti, :width => 80, :height => 14, :at => [-40, -10]
          rescue
            draw_text "GIUNTI SCUOLA", :size => 10, :style => :bold, :at => [-30, 0]
          end
        end
      end
      
      # # Info agente
      # if current_user.present?
      #   draw_text current_user.profile_ragione_sociale, :size => 7, :at => [-40, -30]
      #   draw_text "cell #{current_user.profile_cellulare}", :size => 6, :at => [-40, -40]
      # end
    end
  end

  def agente_ruotato(user)
    # Info agente per intestazione ruotata
    bounding_box([bounds.width / 2.0, bounds.top], :width => bounds.width / 2.0, :height => 100) do
      font_size 8
      text "Agente di Zona - #{user.profile_ragione_sociale}", :size => 10, :align => :right
      text user.profile_indirizzo, :align => :right
      text "#{user.profile_cap} #{user.profile_citta}", :align => :right
      move_down 3
      text "cell #{user.profile_cellulare}", :align => :right
      text "email #{user.profile_email}", :align => :right
      move_down 3
    end
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

  def pieghi_di_libri
    text_box("PIEGHI DI LIBRI",
            at: [0, bounds.top - 250],
            size: 13, style: :bold, rotate: 90)
  end
end