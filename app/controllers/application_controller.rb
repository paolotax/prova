class ApplicationController < ActionController::Base

  include Pagy::Backend

  private

    def require_signin
      unless current_user
        session[:intended_url] = request.url
        redirect_to new_session_url, alert: "Please sign in first!"
      end
    end

    def current_user
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    end

    helper_method :current_user

    def current_user?(user)
      current_user == user
    end

    helper_method :current_user?

    def remember_page
        session[:previous_pages] ||= []
        new_page = url_for(params.to_unsafe_h)
        return unless session[:previous_pages].last != new_page
      
        session[:previous_pages] << new_page if request.get?
        session[:previous_pages] = session[:previous_pages].last(2)
    end

end
