class IsbnMatcherService
  def initialize(user)
    @user = user
    @fuzzy = FuzzyMatch.new([], read: :titolo)
    Rails.logger.debug "IsbnMatcherService inizializzato per user: #{user.id}"
  end

  def match_books(found_books)
    Rails.logger.debug "Ricerca corrispondenze per #{found_books.size} libri"
    matched_books = []
    
    found_books.each do |book|
      Rails.logger.debug "Elaborazione libro: #{book.inspect}"
      
      # Prepariamo il dataset filtrato per classe e disciplina
      dataset = prepare_dataset(book[:classe], book[:disciplina])
      
      
      # Utilizziamo fuzzy_match con il dataset filtrato
      match = @fuzzy.find_with_score(
        book[:title], 
        must_match_at_least_one_word: true,
        threshold: 0.4  # Abbassiamo la soglia per vedere più risultati
      )

      Rails.logger.debug "Match trovato: #{match.inspect}" if match

      if match
        libro, score = match
        matched_books << {
          original_title: book[:title],
          quantity: book[:quantity],
          isbn: libro.codice_isbn,
          matched_title: libro.titolo,
          classe: libro.classe,
          disciplina: libro.disciplina,
          confidence_score: score
        }
      end
    end
    
    Rails.logger.debug "Trovate #{matched_books.size} corrispondenze"
    matched_books
  end

  private

  def prepare_dataset(classe, disciplina)
    query = @user.libri
    
    if classe.present?
      Rails.logger.debug "Filtro per classe: #{classe}"
      query = query.where(classe: classe)
    end
    
    if disciplina.present?
      Rails.logger.debug "Filtro per disciplina: #{disciplina}"
      query = query.where(disciplina: disciplina)
    end
    
    libri = query.to_a
    @fuzzy.haystack = libri
    Rails.logger.debug "Dataset preparato con #{libri.size} libri"
    
    libri
  end
end 