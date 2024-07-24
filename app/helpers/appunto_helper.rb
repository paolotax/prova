module AppuntoHelper


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

