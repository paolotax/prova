class AnarpeImporter
  include ActiveModel::Model

  MATERIE = [
    "MATEMATICA E SCIENZE", "ARTE E IMMAGINE", "SCIENZE MOTORIE",
    "ED. FISICA", "STRUMENTO MUSICALE", "RELIGIONE CATTOLICA",
    "LETTERE", "INGLESE", "FRANCESE", "SPAGNOLO",
    "TEDESCO", "TECNOLOGIA", "MUSICA",
    "RELIGIONE", "SOSTEGNO",
    "ALTERNATIVA", "GEOGRAFIA", "STORIA", "ITALIANO"
  ].freeze

  # Default years when OCR loses digits (middle school = 3 years)
  DEFAULT_YEARS = %w[1 2 3].freeze

  attr_reader :scuola, :imported_count, :updated_count, :errors_list

  def initialize(file:, scuola:)
    @file = file
    @scuola = scuola
    @imported_count = 0
    @updated_count = 0
    @errors_list = []
  end

  def call
    Dir.mktmpdir do |tmpdir|
      insegnanti = []

      page_count = pdf_page_count(@file.path)
      (2..page_count).each do |page_num|
        text = ocr_page(@file.path, page_num, tmpdir)
        insegnanti.concat(parse_insegnanti_from_ocr(text))
      end

      import_insegnanti(insegnanti)
    end
    self
  end

  # Parse the compact ANARPE classi format
  # Handles multiple formats from OCR:
  #   "3C 2F -"          => [["3","C"], ["2","F"]]
  #   "1AF 3B -"         => [["1","A"], ["1","F"], ["3","B"]]
  #   "123 DEF -"        => all combos of 1,2,3 x D,E,F
  #   "- AG-"            => all default years x A,G (no digits = all years)
  #   "- BCE -"          => all default years x B,C,E
  #   "- B1H-"           => extract digits+letters, handle mixed
  def self.parse_classi_compact(text, default_years: DEFAULT_YEARS)
    return [] if text.blank?

    # Normalize: uppercase, strip OCR noise prefix/suffix
    clean = text.upcase.gsub(/\A[:\-=\s]+/, "").gsub(/[\-=\s]+\z/, "").strip
    return [] if clean.blank?

    result = []
    tokens = clean.split(/\s+/)
    pending_digits = []
    found_any_digits = false

    tokens.each do |token|
      if token.match?(/\A\d+\z/)
        # Pure digits token (e.g. "123") — only keep valid year digits (1-5)
        valid = token.chars.select { |d| d.between?("1", "5") }
        pending_digits = valid
        found_any_digits = true if valid.any?
      elsif token.match?(/\A[A-Z]+\z/)
        # Pure letters token (e.g. "DEF", "AG")
        digits_to_use = pending_digits.any? ? pending_digits : nil
        token.chars.each do |l|
          if digits_to_use
            digits_to_use.each { |d| result << [d, l] }
          else
            # No digits available — defer, will apply defaults at end
            result << [nil, l]
          end
        end
        pending_digits = [] if pending_digits.any?
      elsif token.match?(/\d/) && token.match?(/[A-Z]/)
        # Mixed token — extract digits (only valid years 1-5) and letters
        pending_digits = []
        found_any_digits = true

        digits = token.scan(/\d/).select { |d| d.between?("1", "5") }
        letters = token.scan(/[A-Z]/)
        if digits.any?
          letters.each do |l|
            digits.each { |d| result << [d, l] }
          end
        else
          # Digits present but none valid (e.g. "7B") — use defaults
          letters.each { |l| result << [nil, l] }
        end
      end
    end

    # Replace nil years with defaults (when OCR lost the digits)
    if result.any? { |r| r[0].nil? }
      result = result.flat_map do |pair|
        if pair[0].nil?
          default_years.map { |d| [d, pair[1]] }
        else
          [pair]
        end
      end
    end

    result
  end

  private

  def pdf_page_count(path)
    output = `pdfinfo "#{path}" 2>/dev/null`
    match = output.match(/Pages:\s+(\d+)/)
    match ? match[1].to_i : 0
  end

  def ocr_page(pdf_path, page_num, tmpdir)
    png_path = File.join(tmpdir, "page_#{page_num}.png")
    txt_path = File.join(tmpdir, "page_#{page_num}")

    system("gs", "-dNOPAUSE", "-dBATCH", "-sDEVICE=png16m", "-r400",
           "-dFirstPage=#{page_num}", "-dLastPage=#{page_num}",
           "-sOutputFile=#{png_path}", pdf_path,
           out: File::NULL, err: File::NULL)

    system("tesseract", png_path, txt_path, "-l", "ita",
           out: File::NULL, err: File::NULL)

    File.read("#{txt_path}.txt", encoding: "utf-8") rescue ""
  end

  def parse_insegnanti_from_ocr(text)
    insegnanti = []
    lines = text.lines.map(&:strip).reject(&:blank?)

    lines.each_with_index do |line, i|
      # Find lines containing a known subject (longer materie checked first)
      materia = MATERIE.find { |m| line.include?(m) }
      next unless materia

      # Extract the name: uppercase words before the subject
      before_materia = line.split(materia).first.to_s

      # Keep only uppercase words >= 3 chars or containing a dot (M.PIA, M.CRISTINA)
      # Take last 2 parts — format is always COGNOME NOME, noise is at start
      name_parts = before_materia.scan(/[A-Z][A-Z.']+/).select { |w| w.length >= 3 || w.include?(".") }

      # Need at least cognome; nome can be missing (e.g. "CARTA TECNOLOGIA")
      next if name_parts.empty?

      cognome = name_parts.size >= 2 ? name_parts[-2] : name_parts[-1]
      nome = name_parts.size >= 2 ? name_parts[-1] : ""

      # Classes are on the next non-empty line
      # Accept lines with digits+letters (mixed), or just uppercase letters
      # ending with dash (ANARPE format: "- AG-", "7 1AF 3B -", ": EF-")
      classi_text = ""
      if i + 1 < lines.size
        next_line = lines[i + 1]
        if next_line.match?(/[A-Za-z]/) && next_line.match?(/[-–—]/)
          classi_text = next_line
        end
      end

      classi = self.class.parse_classi_compact(classi_text)

      insegnanti << {
        cognome: cognome,
        nome: nome,
        materia: materia,
        classi: classi
      }
    end

    insegnanti
  end

  def import_insegnanti(insegnanti)
    insegnanti.each do |data|
      persona = scuola.persone.find_or_initialize_by(
        cognome: data[:cognome],
        nome: data[:nome],
        account: scuola.account
      )
      is_new = persona.new_record?
      persona.ruolo = :docente
      persona.save!

      data[:classi].each do |classe_parts|
        next if classe_parts.size < 2
        anno = classe_parts[0]
        sezione = classe_parts[1]

        classe = scuola.classi.find_by(anno_corso: anno, sezione: sezione)
        next unless classe

        PersonaClasse.find_or_create_by!(persona: persona, classe: classe) do |pc|
          pc.materia = data[:materia]
        end
      end

      if is_new
        @imported_count += 1
      else
        @updated_count += 1
      end
    rescue => e
      @errors_list << "#{data[:cognome]} #{data[:nome]}: #{e.message}"
    end
  end
end
