# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format
# (all these examples are active by default):

ActiveSupport::Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   
  inflect.acronym 'MCP'
  inflect.acronym 'LLM'
  
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

  inflect.irregular 'ordine', 'ordini'
  inflect.irregular 'vendita', 'vendite'
  inflect.irregular 'giacenza', 'giacenze'

  inflect.irregular 'carico', 'carichi'
  inflect.irregular 'scarichi', 'scarichi'

  inflect.irregular 'buono di consegna', 'buoni di consegna'
  inflect.irregular 'nota di accredito', 'note di accredito'

  inflect.irregular 'bolla di carico', 'bolle di carico'
  inflect.irregular 'resa a fornitore', 'rese a fornitore'
  inflect.irregular 'fattura acquisti', 'fatture acquisti'


  inflect.irregular 'causale', 'causali'
  inflect.irregular 'documento', 'documenti'
  inflect.irregular 'editore', 'editori'

  inflect.irregular 'consegna', 'consegne'

  inflect.irregular 'articolo', 'articoli'
  inflect.irregular 'utente',   'utenti'

  inflect.irregular 'user_editore',   'user_editori'
  inflect.irregular 'mandato',   'mandati'


  inflect.irregular 'tipo_scuola', 'tipi_scuole'
  inflect.irregular 'zona', 'zone'

  inflect.irregular 'adozione_elementare', 'adozioni_elementari'

  inflect.irregular 'confezione', 'confezioni'
  inflect.irregular 'fascicolo', 'fascicoli'

  inflect.irregular 'azienda', 'aziende'

  inflect.irregular 'ssk_appunto_backup', 'ssk_appunti_backup'

  # inflect.irregular 'documento_riga', 'documenti_righe'

  # inflect.plural /^([\w]*)a/i, '\1e'
  # inflect.singular /^([\w]*)e/i, '\1a'
  # inflect.plural /^([\w]*)o/i, '\1i'
  # inflect.singular /^([\w]*)i/i, '\1o'

  # inflect.uncountable %w( fish sheep )

  # Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end
end
