class SearchController < ApplicationController
  def index
    @import_scuole = current_user.import_scuole.search_all_word(params[:query])
  end
end
