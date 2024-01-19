# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format
# (all these examples are active by default):

ActiveSupport::Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
  inflect.irregular 'cliente', 'clienti'
  inflect.irregular 'fornitore', 'fornitori'
  inflect.irregular 'scuola', 'scuole'
  inflect.irregular 'appunto', 'appunti'
  inflect.irregular 'persona', 'persone'
  inflect.irregular 'visita', 'visite'   
  inflect.irregular 'indirizzo', 'indirizzi'
  inflect.irregular 'telefono', 'telefoni'
  inflect.irregular 'libro', 'libri'
  inflect.irregular 'librino', 'librini'
  inflect.irregular 'riga', 'righe'
  inflect.irregular 'fattura', 'fatture'
  inflect.irregular 'insegnante', 'insegnanti'
  inflect.irregular 'classe', 'classi'
  inflect.irregular 'adozione', 'adozioni'
  inflect.irregular 'materia', 'materie'
  inflect.irregular 'tappa', 'tappe'
  inflect.irregular 'sezione', 'sezioni'
  inflect.irregular 'giro', 'giri'
  inflect.irregular 'copia', 'copie'
  inflect.irregular 'comune', 'comuni'
  inflect.irregular 'magazzino', 'magazzini'


  inflect.irregular 'carico', 'carichi'
  inflect.irregular 'scarichi', 'scarichi'

  inflect.irregular 'buono di consegna', 'buoni di consegna'
  inflect.irregular 'nota di accredito', 'note di accredito'
  
  inflect.irregular 'bolla di carico', 'bolle di carico'
  inflect.irregular 'resa a fornitore', 'rese a fornitore'
  inflect.irregular 'fattura acquisti', 'fatture acquisti'
  
  

  inflect.irregular 'ordine', 'ordini'

  inflect.irregular 'causale', 'causali'
  inflect.irregular 'documento', 'documenti'
  inflect.irregular 'editore', 'editori'

  inflect.irregular 'consegna', 'consegne'

  inflect.irregular 'articolo', 'articoli'
  inflect.irregular 'utente',   'utenti'

  inflect.irregular 'user_editore',   'user_editori'

  inflect.irregular 'tipogrado_tipo_scuola', 'gradi_tipi_scuole'



  # inflect.irregular 'documento_riga', 'documenti_righe'
  
  # inflect.plural /^([\w]*)a/i, '\1e'
  # inflect.singular /^([\w]*)e/i, '\1a'
  # inflect.plural /^([\w]*)o/i, '\1i'
  # inflect.singular /^([\w]*)i/i, '\1o'
  
  # inflect.uncountable %w( fish sheep )
end
