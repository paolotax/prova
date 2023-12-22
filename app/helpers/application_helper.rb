module ApplicationHelper


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




def toggle_button_tag( checked = true, label = "" ) 
  
  # button_css  <!-- Enabled: "bg-indigo-600", Not Enabled: "bg-gray-200" -->
  # span_css    <!-- Enabled: "translate-x-5", Not Enabled: "translate-x-0" -->

  if checked
    button_css = "bg-indigo-600"
    span_css   = "translate-x-5"
  else
    button_css = "bg-gray-200"
    span_css   = "translate-x-0"
  end
    
  render partial: "layouts/toggle_button", locals: { checked: checked, label: label, button_css: button_css, span_css: span_css }

end

end
