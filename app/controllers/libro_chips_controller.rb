class LibroChipsController < ApplicationController
    
  before_action :set_libri, except: :new_possibly_new
  
  def new
    render turbo_stream: helpers.combobox_selection_chips_for(@libri)
  end

  def new_html
  end

  def new_dismissing
    render turbo_stream: helpers.dismissing_combobox_selection_chips_for(@libri)
  end

  def new_possibly_new
    @libri = params[:combobox_values].split(",").map do |value|
      current_user.libri.find_by(id: value) || OpenStruct.new(to_combobox_display: value, id: value)
    end
    render turbo_stream: helpers.combobox_selection_chips_for(@libri)
  end

  private
    
    def set_libri
      @libri = current_user.libri.find params[:combobox_values].split(",")
    end

end