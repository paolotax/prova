module ApplicationHelper


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


end
