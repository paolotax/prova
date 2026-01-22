module AppuntoHelper

  # Returns golden-effect class if appunto is golden
  def appunto_golden_class(appunto)
    appunto.golden? ? "golden-effect" : ""
  end

  # Returns BEM modifier class based on appunto state (from concerns)
  def appunto_stato_modifier(appunto)
    return "card--closed" if appunto.closed?
    return "card--postponed" if appunto.postponed?
    return "card--golden" if appunto.golden?
    ""
  end

  # Returns CSS color for card-perma based on appunto state (from concerns)
  # Colors aligned with Fizzy: gray for closed/postponed, blue for maybe/triage
  def appunto_color(appunto)
    return "var(--color-golden)" if appunto.golden?
    return "oklch(0.6 0.01 0)" if appunto.closed?     # gray
    return "oklch(0.6 0.01 0)" if appunto.postponed?  # gray
    return appunto.entry.column.color if appunto.entry&.column&.color.present?  # column color
    "oklch(var(--lch-blue-medium))"                   # blue (maybe/triage)
  end

  def attachment_icon_tag(attachment)
    
    # suggerito da copilot lo provo
    case attachment.content_type
      when "application/pdf"
        inline_svg_tag "icon-pdf.svg" 
      when "application/msword"
        inline_svg_tag "icon-word.svg" 
      when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        inline_svg_tag "icon-word.svg" 
      when "application/vnd.ms-excel"
        inline_svg_tag "icon-excel.svg" 
      when "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        inline_svg_tag "icon-excel.svg" 
      when "application/vnd.ms-powerpoint"
        inline_svg_tag "icon-ppt.svg" 
      when "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        inline_svg_tag "icon-ppt.svg" 
      when "application/zip"
        inline_svg_tag "icon-zip.svg" 
      when "application/x-rar-compressed"
        inline_svg_tag "icon-zip.svg" 
      when "application/x-7z-compressed"
        inline_svg_tag "icon-zip.svg" 
      when "application/x-tar"
        inline_svg_tag "icon-zip.svg" 
      when "application/x-gzip"
        inline_svg_tag "icon-zip.svg" 
      when "application/x-bzip2"
        inline_svg_tag "icon-zip.svg"
      when "video/mp4"
        inline_svg_tag "icon-video.svg"
      else
        inline_svg_tag "icon-file.svg" 
    end
  end



end

