class GiroChipsController < ApplicationController
    
  before_action :set_giri, except: :create_possibly_new

  def create
    render turbo_stream: helpers.combobox_selection_chips_for(@giri)
  end

  def create_html
  end

  def create_dismissing
    render turbo_stream: helpers.dismissing_combobox_selection_chips_for(@giri)
  end

  def create_possibly_new
    @giri = params[:combobox_values].split(",").map do |value|
      current_user.giri.find_by(id: value) || OpenStruct.new(to_combobox_display: value, id: value)
    end

    render turbo_stream: helpers.combobox_selection_chips_for(@giri)
  end

  private
    
    def set_giri
      @giri = current_user.giri.find params[:combobox_values].split(",")
    end

end