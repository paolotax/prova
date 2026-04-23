class ApplicationController < ActionController::Base

  include Pundit::Authorization

  include PasswordlessAuthentication
  include AccountFromUrl

  include BlockSearchEngineIndexing
  include CurrentRequest, CurrentTimezone, SetPlatform
  include RequestForgeryProtection
  include TurboFlash, ViewTransitions
  include RoutingHeaders

  # etag { "v1" }
  # stale_when_importmap_changes
  # allow_browser versions: :modern



  # allow_browser versions: :modern

  before_action :set_current_request_identifier
  before_action :authenticate_user!

  # Inietta automaticamente account_id in tutti i path helpers
  # Solo se siamo in una route con account context
  def default_url_options
    if params[:account_id].present? && Current.account
      { account_id: Current.account.id }
    else
      {}
    end
  end

  private

    def set_current_request_identifier
      Current.request_id = request.request_id
    end

    def paginate_json(scope, default_limit: 50, max_limit: 200)
      @total = scope.size
      limit = (params[:limit].presence || default_limit).to_i.clamp(1, max_limit)
      offset = [params[:offset].to_i, 0].max
      scope.offset(offset).limit(limit)
    end

    def remember_page
        session[:previous_pages] ||= []
        new_page = url_for(params.to_unsafe_h)
        return unless session[:previous_pages].last != new_page

        session[:previous_pages] << new_page if request.get?
        session[:previous_pages] = session[:previous_pages].last(2)
    end

end
