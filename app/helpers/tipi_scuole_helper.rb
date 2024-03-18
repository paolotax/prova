module TipiScuoleHelper

  def grado_label(grado)
    case grado
    when 'I'
      'infanzia'
    when 'E'
      'primaria'
    when 'M'
      'secondaria I grado'
    when 'N'
      'secondaria II grado'
    when 'altro'
      'altro'
    else
      grado
    end
  end

end
