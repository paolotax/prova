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
    
    # Prendi tutte le scuole dell'utente che non hanno tappe in questo giro
    scuole_senza_tappe = Current.user.import_scuole
                          .where.not(id: @giro.tappe.where(tappable_type: 'ImportScuola').select(:tappable_id))
                          .includes(:direzione, :user_scuole)
                          .order('user_scuole.position')
    
    scuole_senza_tappe = scuole_senza_tappe.where.not(id: @giro.excluded_ids)

    # Raggruppa per comune della direzione o della scuola e ordina alfabeticamente
    {nil => scuole_senza_tappe.group_by { |s| 
      if s.direzione.present?
        s.direzione.DESCRIZIONECOMUNE
      else
        s.DESCRIZIONECOMUNE
      end
    }.sort.to_h}
  end

  def tappe_programmate
    @tappe.programmate
          .order(:data_tappa, :position)
          .includes(:tappable)
          .group_by(&:data_tappa)
          .transform_values do |tappe_del_giorno|
            tappe_del_giorno.group_by { |t| t.tappable.DESCRIZIONECOMUNE if t.tappable.respond_to?(:DESCRIZIONECOMUNE) }
          end
  end

  def tappe_completate
    @tappe.completate
          .order(data_tappa: :desc, position: :asc)
          .includes(:tappable)
          .group_by(&:data_tappa)
          .transform_values do |tappe_del_giorno|
            tappe_del_giorno.group_by { |t| t.tappable.DESCRIZIONECOMUNE if t.tappable.respond_to?(:DESCRIZIONECOMUNE) }
          end
  end
end 