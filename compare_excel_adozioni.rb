#!/usr/bin/env ruby

# Script per confrontare il file Excel dell'editore con le mie_adozioni
# Da eseguire nel Rails console: rails console
# Poi: load 'compare_excel_adozioni.rb'

puts "="*80
puts "CONFRONTO FILE EXCEL EDITORE CON MIE_ADOZIONI"
puts "="*80

# Funzione helper per trovare utenti
def find_users
  puts "\nUtenti disponibili nel sistema:"
  User.all.each do |user|
    puts "  #{user.id}: #{user.email} (#{user.miei_editori&.length || 0} editori)"
  end
end

# Funzione helper per vedere gli editori di un utente
def show_user_editori(user)
  puts "\nEditori per #{user.email}:"
  user.miei_editori.each do |editore|
    puts "  #{editore}"
  end
end

# Funzione per leggere il file Excel
def read_excel_file(file_path)
  require 'roo'
  
  xlsx = Roo::Spreadsheet.open(file_path)
  xlsx.default_sheet = xlsx.sheets.first
  
  puts "\nFile Excel dell'editore:"
  puts "- Righe totali: #{xlsx.last_row}"
  puts "- Colonne: #{xlsx.last_column}"
  
  # Leggi header
  header = xlsx.row(1)
  puts "\nColonne nel file Excel:"
  header.each_with_index do |col, index|
    puts "  #{index + 1}: #{col}"
  end
  
  # Analizza i dati Excel
  excel_data = []
  total_alunni = 0
  
  (2..xlsx.last_row).each do |row_num|
    row = xlsx.row(row_num)
    row_data = Hash[header.zip(row)]
    
    excel_data << {
      cod_agente: row_data['Cod. Agente'],
      anno: row_data['Anno'],
      cod_ministeriale: row_data['CodMinisteriale'],
      descrizione: row_data['Descrizione'],
      indirizzo: row_data['Indirizzo'],
      cap: row_data['CAP'],
      comune: row_data['Comune'],
      provincia: row_data['Provincia'],
      editore: row_data['Editore'],
      ean: row_data['Ean'],
      titolo: row_data['Titolo'],
      classe: row_data['Classe'],
      sezione: row_data['Sezione'],
      alunni: row_data['Alunni'].to_i
    }
    
    total_alunni += row_data['Alunni'].to_i
  end
  
  return excel_data, total_alunni
end

# Funzione per confrontare con il database
def compare_with_database(excel_data, user = nil)
  puts "\n" + "="*80
  puts "CONFRONTO CON DATABASE"
  puts "="*80
  
  # Estrai i codici EAN dal file Excel
  excel_ean_codes = excel_data.map { |r| r[:ean] }.compact.uniq
  
  puts "\nCodici EAN nel file Excel: #{excel_ean_codes.length}"
  
  # Confronta con le tue adozioni
  if user
    # Usa l'utente specificato
    mie_adozioni = ImportAdozione.where(EDITORE: user.miei_editori)
    puts "Adozioni per #{user.email}: #{mie_adozioni.count}"
  else
    # Mostra tutte le adozioni se non c'è utente
    mie_adozioni = ImportAdozione.all
    puts "Tutte le adozioni nel database: #{mie_adozioni.count}"
    puts "⚠️  Per confrontare con le TUE adozioni, specifica un utente"
  end
  
  # Trova corrispondenze per ISBN/EAN
  mie_ean_codes = mie_adozioni.pluck(:CODICEISBN).compact.uniq
  puts "Tue adozioni con ISBN: #{mie_ean_codes.length}"
  
  # Intersezione tra Excel e database
  ean_in_both = excel_ean_codes & mie_ean_codes
  puts "ISBN presenti in entrambi: #{ean_in_both.length}"
  
  # Solo nel file Excel
  ean_only_excel = excel_ean_codes - mie_ean_codes
  puts "ISBN solo nel file Excel: #{ean_only_excel.length}"
  
  # Solo nel database
  ean_only_db = mie_ean_codes - excel_ean_codes
  puts "ISBN solo nel database: #{ean_only_db.length}"
  
  return ean_in_both, ean_only_excel, ean_only_db
end

# Funzione per analizzare le scuole
def analyze_schools(excel_data, user = nil)
  puts "\n" + "="*80
  puts "ANALISI SCUOLE"
  puts "="*80
  
  scuole_excel = excel_data.group_by { |r| r[:cod_ministeriale] }
  
  puts "Scuole nel file Excel: #{scuole_excel.keys.length}"
  
  # Confronta con le scuole nel database
  if user
    mie_scuole = ImportScuola.joins(:import_adozioni)
                             .where(import_adozioni: ImportAdozione.where(EDITORE: user.miei_editori))
                             .distinct
    puts "Scuole con adozioni per #{user.email}: #{mie_scuole.count}"
  else
    mie_scuole = ImportScuola.joins(:import_adozioni).distinct
    puts "Tutte le scuole con adozioni: #{mie_scuole.count}"
    puts "⚠️  Per confrontare con le TUE scuole, specifica un utente"
  end
  
  scuole_db_codes = mie_scuole.pluck(:CODICESCUOLA).compact.uniq
  scuole_excel_codes = scuole_excel.keys.compact.uniq
  
  scuole_in_both = scuole_excel_codes & scuole_db_codes
  puts "Scuole presenti in entrambi: #{scuole_in_both.length}"
  
  scuole_only_excel = scuole_excel_codes - scuole_db_codes
  puts "Scuole solo nel file Excel: #{scuole_only_excel.length}"
  
  scuole_only_db = scuole_db_codes - scuole_excel_codes
  puts "Scuole solo nel database: #{scuole_only_db.length}"
  
  return scuole_in_both, scuole_only_excel, scuole_only_db
end

# Funzione per calcolare le quantità
def calculate_quantities(excel_data, ean_in_both)
  puts "\n" + "="*80
  puts "CALCOLO QUANTITÀ DA ORDINARE"
  puts "="*80
  
  # Raggruppa per ISBN e calcola totale alunni
  quantities = excel_data.group_by { |r| r[:ean] }
                        .transform_values { |records| records.sum { |r| r[:alunni] } }
  
  puts "\nQuantità per ISBN (solo quelli presenti nel database):"
  quantities.each do |ean, alunni|
    if ean_in_both.include?(ean)
      puts "  #{ean}: #{alunni} alunni"
    end
  end
  
  total_alunni_db_books = quantities.select { |ean, _| ean_in_both.include?(ean) }
                                   .values.sum
  
  puts "\nTotale alunni per libri presenti nel database: #{total_alunni_db_books}"
  
  return quantities
end

# Funzione principale
def main(file_path, user = nil)
  begin
    # Leggi il file Excel
    excel_data, total_alunni = read_excel_file(file_path)
    
    puts "\nStatistiche Excel:"
    puts "- Record totali: #{excel_data.length}"
    puts "- Totale alunni: #{total_alunni}"
    puts "- Editori unici: #{excel_data.map { |r| r[:editore] }.uniq.length}"
    puts "- Scuole uniche: #{excel_data.map { |r| r[:cod_ministeriale] }.uniq.length}"
    
    puts "\nEditori nel file Excel:"
    excel_data.map { |r| r[:editore] }.uniq.each do |editore|
      count = excel_data.count { |r| r[:editore] == editore }
      alunni_editore = excel_data.select { |r| r[:editore] == editore }.sum { |r| r[:alunni] }
      puts "  #{editore}: #{count} record, #{alunni_editore} alunni"
    end
    
    # Confronta con il database
    ean_in_both, ean_only_excel, ean_only_db = compare_with_database(excel_data, user)
    
    # Analizza le scuole
    scuole_in_both, scuole_only_excel, scuole_only_db = analyze_schools(excel_data, user)
    
    # Calcola le quantità
    quantities = calculate_quantities(excel_data, ean_in_both)
    
    puts "\n" + "="*80
    puts "RIEPILOGO FINALE"
    puts "="*80
    puts "Il file Excel contiene #{excel_data.length} record con #{total_alunni} alunni totali."
    puts "ISBN presenti in entrambi: #{ean_in_both.length}"
    puts "Scuole presenti in entrambi: #{scuole_in_both.length}"
    puts "Il campo 'Alunni' è la principale differenza rispetto alle tue import_adozioni."
    
    return {
      excel_data: excel_data,
      total_alunni: total_alunni,
      ean_in_both: ean_in_both,
      ean_only_excel: ean_only_excel,
      ean_only_db: ean_only_db,
      scuole_in_both: scuole_in_both,
      scuole_only_excel: scuole_only_excel,
      scuole_only_db: scuole_only_db,
      quantities: quantities
    }
    
  rescue => e
    puts "Errore nella lettura del file Excel: #{e.message}"
    return nil
  end
end

# Istruzioni per l'uso
puts "\n" + "="*80
puts "ISTRUZIONI PER L'USO"
puts "="*80
puts "1. Assicurati che il file Excel sia nella directory corrente"
puts "2. Per confrontare con tutte le adozioni:"
puts "   result = main('Adozioni202526.xlsx')"
puts "3. Per confrontare con le TUE adozioni:"
puts "   user = User.find_by(email: 'tua@email.com')"
puts "   result = main('Adozioni202526.xlsx', user)"
puts "4. I risultati saranno salvati nella variabile 'result'"
puts "5. Puoi accedere ai dati con: result[:excel_data], result[:quantities], etc."
puts "\nEsempi:"
puts "  result = main('Adozioni202526.xlsx')  # Tutte le adozioni"
puts "  user = User.first"
puts "  result = main('Adozioni202526.xlsx', user)  # Solo le tue adozioni"
puts "  result[:ean_in_both]  # ISBN presenti in entrambi"
puts "  result[:quantities]  # Quantità per ISBN"