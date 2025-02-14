class Tappe::GroupByDateService
  def initialize(tappe, filter = nil)
    @tappe = tappe
    @filter = filter
  end

  def call
    tappe_filtrate = case @filter
                     when 'da programmare'
                       @tappe.da_programmare.per_ordine_e_data
                     when 'programmate'
                       @tappe.programmate.order(:data_tappa, :position)
                     when 'completate'
                       @tappe.completate.order(data_tappa: :desc, position: :asc)
                     else
                       @tappe
                     end

    tappe_filtrate
      .includes(:tappable)
      .group_by(&:data_tappa)
      .transform_values do |tappe_del_giorno|
        tappe_del_giorno.group_by { |t| t.tappable.DESCRIZIONECOMUNE if t.tappable.respond_to?(:DESCRIZIONECOMUNE) }
      end
  end
end 