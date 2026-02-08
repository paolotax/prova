module SearchHelper
  def search_result_path(record)
    case record
    when Scuola    then scuola_path(Current.account, record)
    when Libro     then libro_path(Current.account, record)
    when Cliente   then cliente_path(Current.account, record)
    when Documento then documento_path(Current.account, record)
    when Appunto   then appunto_path(Current.account, record)
    when Classe    then scuola_path(Current.account, record.scuola)
    when Persona   then record.scuola ? scuola_path(Current.account, record.scuola) : scuole_path(Current.account)
    end
  end

  def search_result_label(record)
    case record
    when Scuola    then "#{record.denominazione} - #{record.comune}"
    when Libro     then "#{record.titolo} - #{record.editore&.editore}"
    when Cliente   then "#{record.denominazione} - #{record.comune}"
    when Documento then "#{record.numero_documento} #{record.causale&.causale} - #{record.clientable}"
    when Appunto   then "#{record.nome} - #{record.denominazione}"
    when Classe    then "#{record.denominazione} - #{record.comune}"
    when Persona   then record.to_combobox_display
    end
  end
end
