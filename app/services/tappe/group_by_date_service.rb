class Tappe::GroupByDateService
  def initialize(tappe, filter = nil, giro = nil)
    @tappe = tappe
    @filter = filter
    @giro = giro
  end

  def call
    case @filter
    when 'da programmare'
      scuole_senza_tappe
    when 'programmate'
      tappe_programmate
    when 'completate'
      tappe_completate
    else
      @tappe
    end
  end

  private

  def scuole_senza_tappe
    return {} unless @giro

    scuole = Current.account.scuole
                      .where.not(id: @giro.tappe.where(tappable_type: 'Scuola').select(:tappable_id))
                      .order(:posizione)

    scuole = scuole.where.not(id: @giro.excluded_ids)

    {nil => scuole.group_by(&:comune).sort.to_h}
  end

  def tappe_programmate
    @tappe.programmate
          .order(:data_tappa, :position)
          .includes(:tappable)
          .group_by(&:data_tappa)
          .transform_values do |tappe_del_giorno|
            tappe_del_giorno.group_by { |t| t.tappable.comune if t.tappable.respond_to?(:comune) }
          end
  end

  def tappe_completate
    @tappe.completate
          .order(data_tappa: :desc, position: :asc)
          .includes(:tappable)
          .group_by(&:data_tappa)
          .transform_values do |tappe_del_giorno|
            tappe_del_giorno.group_by { |t| t.tappable.comune if t.tappable.respond_to?(:comune) }
          end
  end
end
