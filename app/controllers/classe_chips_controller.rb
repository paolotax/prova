class ClasseChipsController < ApplicationController
    
  before_action :set_classi, except: :create_possibly_new

  def create
    render turbo_stream: helpers.combobox_selection_chips_for(@classi)
  end

  def create_html
  end

  def create_dismissing
    render turbo_stream: helpers.dismissing_combobox_selection_chips_for(@classi)
  end

  def create_possibly_new
    @classi = params[:combobox_values].split(",").map do |value|
      Views::Classe.find_by(id: value) || OpenStruct.new(to_combobox_display: value, id: value)
    end

    render turbo_stream: helpers.combobox_selection_chips_for(@classi)
  end

  private

      def set_classi
        @classi = Views::Classe.find params[:combobox_values].split(",")
      end

  
  end