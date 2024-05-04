module ApplicationHelper

  include Pagy::Frontend

  def tempo_trascorso( data_inizio, data_fine = Time.now )

    data_inizio = Time.parse(data_inizio) if data_inizio.is_a? String
    data_fine   = Time.parse(data_fine)   if data_fine.is_a? String

    data_inizio = data_inizio.to_time if data_inizio.is_a? Date
    data_fine   = data_fine.to_time   if data_fine.is_a? Date

    seconds = (data_fine - data_inizio).to_i
    
    minutes = seconds / 60
    hours   = minutes / 60
    days    = hours / 24
    months  = days / 30
    years   = months / 12

    resto_seconds = seconds % 60
    resto_minutes = minutes % 60

    if years > 0
      "#{years} anni"
    elsif months > 0
      "#{months} mesi"
    elsif days > 0
      "#{days} giorni"
    elsif hours > 0
      "#{hours} ore"
    elsif minutes > 0
      "#{minutes}min:#{resto_seconds}sec"
    else
      "#{seconds} secondi"
    end
  
  end

  def params_split(params)
    if params.present?
      params.split
    else
      ""
    end
  end

  def titleize_con_apostrofi(stringa)
    stringa.titleize.gsub("'e", "'E").gsub("'i", "'I").gsub("'a", "'A").gsub("'o", "'O").gsub("'u", "'U")
  end
  
  def go_to_scuola_path(scuola, provider = 'waze')
    if provider == 'waze'
      "https://waze.com/ul?q=#{u scuola.indirizzo_navigator}"
    elsif provider == 'google'
      "https://www.google.com/maps/search/?api=1&query=#{u scuola.indirizzo_navigator}"
    elsif provider == 'apple'
      "https://maps.apple.com/?q=#{u scuola.indirizzo_navigator}"
    end
  end


  def link_to_previous_page(link_title)
    return unless session[:previous_pages].present?
    link_to(link_title, session[:previous_pages].first, class: "block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
    )
  end
  # stack overflow 70960161 examle

  #   # in the contracts_controller.rb
  #   def destroy
  #     @contract = Contract.find(params[:id]).destroy
    
  #     if session[:previous_pages].present? && request.original_url == session[:previous_pages][1]
  #       session[:previous_pages] = session[:previous_pages].first(1)
  #     end
  #     flash[:notice] = 'Contract was successfully deleted.'
    
  #     redirect_to action: 'index'
  #   end


  
  def embedded_svg(filename, options = {})
    assets = Rails.application.assets
    asset = assets.find_asset(filename)
    if asset
      file = asset.source.force_encoding("UTF-8")
      doc = Nokogiri::HTML::DocumentFragment.parse file
      svg = doc.at_css "svg"
      svg["class"] = options[:class] if options[:class].present?
    else
      doc = "<!-- SVG #{filename} not found -->"
    end
    raw doc
  end

  def toggle_button_tag( checked = true, label = "", html_id = nil ) 
    #             TailwindUI
    # button_css  <!-- Enabled: "bg-indigo-600", Not Enabled: "bg-gray-200" -->
    # span_css    <!-- Enabled: "translate-x-5", Not Enabled: "translate-x-0" -->
    if checked
      button_css = "bg-gray-900"
      span_css   = "translate-x-5"
    else
      button_css = "bg-gray-200"
      span_css   = "translate-x-0"
    end      
    render partial: "layouts/toggle_button", locals: { html_id: html_id, checked: checked, label: label, button_css: button_css, span_css: span_css }
  end

end
