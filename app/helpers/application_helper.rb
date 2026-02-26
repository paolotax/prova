module ApplicationHelper
  def page_title_tag
    account_name = Current.account&.name if Current.user&.accounts&.many?
    tag.title [@page_title, account_name, "Scagnozz"].compact.join(" | ")
  end

  def icon_tag(name, **options)
    tag.span class: class_names("icon icon--#{name}", options.delete(:class)), "aria-hidden": true, **options
  end

  def back_link_to(label, url, **options)
    action = "keydown.esc@document->hotkey#click click->turbo-navigation#backIfSamePath"
    link_to url, class: "btn btn--back", data: { controller: "hotkey", action: action }, **options do
      icon_tag("arrow-left") + tag.strong("Torna a #{label}", class: "overflow-ellipsis") + tag.kbd("ESC", class: "txt-x-small hide-on-touch").html_safe
    end
  end

  def back_link_to_url(label, url, **options)
    action = "keydown.esc@document->hotkey#click"
    link_to url, class: "btn btn--back", data: { controller: "hotkey", action: action }, **options do
      icon_tag("arrow-left") + tag.strong("Torna a #{label}", class: "overflow-ellipsis") + tag.kbd("ESC", class: "txt-x-small hide-on-touch").html_safe
    end
  end

  # Simple header back link button (for content_for :header)
  def header_back_link(path, label: nil)
    link_to path, class: "btn" do
      icon_tag("arrow-left", size: "small") +
        tag.span(label || "Indietro", class: "for-screen-reader")
    end
  end

  def referrer_back_info
    return nil unless request.referrer.present?

    begin
      uri = URI.parse(request.referrer)
      route = Rails.application.routes.recognize_path(uri.path)

      label = case route[:controller]
              when "documenti" then "Documenti"
              when "appunti"   then "Appunti"
              when "tappe"     then "Tappe"
              when "clienti"   then "Clienti"
              when "scuole"    then "Scuole"
              when "dashboard" then "Dashboard"
              when "entries"   then "Kanban"
              else nil
              end

      return nil unless label

      { label: label, path: request.referrer }
    rescue ActionController::RoutingError, URI::InvalidURIError
      nil
    end
  end




  def new_appunto_link(appuntabile, style: :icon)
    path = new_appunto_path(appuntabile_type: appuntabile.class.name, appuntabile_id: appuntabile.id)
    if style == :button
      link_to path, class: "btn btn--link full-width", data: { turbo_frame: "_top" } do
        icon_tag("pencil") + tag.span("Nuovo Appunto")
      end
    else
      link_to path, class: "btn", data: { controller: "tooltip", turbo_frame: "_top" } do
        icon_tag("note") + tag.span("Nuovo Appunto", class: "for-screen-reader")
      end
    end
  end

  BLANK_SLATES = {
    clienti:   { title: "Nessun cliente trovato",   empty: "il primo cliente",   icon: "users",            label: "Cliente",   path: :new_cliente_path },
    libri:     { title: "Nessun libro trovato",     empty: "il primo libro",     icon: "book",             label: "Libro",     path: :new_libro_path },
    scuole:    { title: "Nessuna scuola trovata",   empty: "la prima scuola",    icon: "building-library", label: "Scuola",    path: :new_scuola_path },
    appunti:   { title: "Nessun appunto trovato",   empty: "il primo appunto",   icon: "note",             label: "Appunto",   path: :appunti_path, method: :post },
    documenti: { title: "Nessun documento trovato", empty: "il primo documento", icon: "document",         label: "Documento", path: :new_documento_path },
  }.freeze

  def blank_slate_for(key, filtering: nil)
    config = BLANK_SLATES[key]
    return unless config

    filters_active = filtering&.filters_active?

    tag.div(class: "blank-slate blank-slate--empty") do
      concat tag.h3(config[:title], class: "txt-large font-weight-bold")
      concat tag.p(class: "txt-small txt-subtle margin-block-end") {
        filters_active ? "Prova a modificare i filtri di ricerca." : "Inizia aggiungendo #{config[:empty]}."
      }
      unless filters_active
        url = send(config[:path])
        if config[:method] == :post
          concat button_to(url, method: :post, class: "btn btn--primary", form: { data: { turbo: false } }) {
            icon_tag(config[:icon], size: "small") + " Aggiungi #{config[:label]}".html_safe
          }
        else
          concat link_to(url, class: "btn btn--primary", data: { turbo_frame: "_top" }) {
            icon_tag(config[:icon], size: "small") + " Aggiungi #{config[:label]}".html_safe
          }
        end
      end
    end
  end

  def turbo_id_for(obj)
    obj.persisted? ? obj.id : obj.hash
  end

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
  
  def link_to_previous_page(link_title)
    return unless session[:previous_pages].present?
    link_to(link_title, session[:previous_pages].first, class: "block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
    )
  end
    
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
      button_css = "bg-gray-100"
      span_css   = "translate-x-0"
    end      
    render partial: "layouts/toggle_button", locals: { html_id: html_id, checked: checked, label: label, button_css: button_css, span_css: span_css }
  end

  def string_to_tailwind_color(str)
    
    return "bg-gray-100" if str.blank?
    
    hash = str.to_s[0..2].bytes.sum
    # Array di classi Tailwind per 5 diversi colori
    colors = [
      "bg-blue-500 text-white",
      "bg-green-500 text-white", 
      "bg-purple-500 text-white",
      "bg-orange-500 text-white",
      "bg-pink-500 text-white"
    ]

    # Seleziona un colore basato sul modulo del hash
    colors[hash % colors.length]
  end

  def appuntabile_avatar_abbreviation(appuntabile)
    return "" unless appuntabile

    # Ottieni il nome base dell'entità
    nome = case appuntabile
           when Scuola
             appuntabile.denominazione.to_s
           when Cliente
             appuntabile.denominazione.to_s
           when Classe
             "#{appuntabile.anno_corso}#{appuntabile.sezione}"
           when Persona
             "#{appuntabile.cognome} #{appuntabile.nome}".strip
           else
             appuntabile.to_s
           end

    # Rimuovi caratteri speciali e parole non necessarie
    nome_pulito = nome
      .gsub(/[^\w\s]/, '')
      .gsub(/\b(SCUOLA|PRIMARIA)\b/, '')
      .strip

    # Prendi le prime due lettere
    prime_lettere = nome_pulito[0..1].to_s.titleize

    # Prendi la prima lettera della città/comune se disponibile
    citta = appuntabile.try(:comune) || appuntabile.try(:citta_scuola)
    iniziale_citta = citta.to_s[0].to_s.upcase

    (prime_lettere + iniziale_citta)
  end

  def scuola_avatar_abbreviation(import_scuola)
    return "" unless import_scuola

    # Rimuovi caratteri speciali e parole non necessarie
    nome_pulito = import_scuola.scuola
      .gsub(/[^\w\s]/, '') # rimuove caratteri speciali
      .gsub(/\b(SCUOLA|PRIMARIA)\b/, '') # rimuove "SCUOLA" e "PRIMARIA"
      .strip

    # Prendi le prime due lettere del nome della scuola
    prime_lettere = nome_pulito[0..1].titleize

    # Prendi la prima lettera della città
    iniziale_citta = import_scuola.citta_scuola.to_s[0].upcase

    # Combina le lettere e assicurati che sia maiuscolo
    (prime_lettere + iniziale_citta)
  end

end
