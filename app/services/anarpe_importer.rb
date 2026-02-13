class AnarpeImporter
  include ActiveModel::Model

  attr_reader :scuola, :imported_count, :errors_list

  def initialize(file:, scuola:)
    @file = file
    @scuola = scuola
    @imported_count = 0
    @errors_list = []
  end

  def call
    reader = PDF::Reader.new(@file)
    insegnanti = []

    reader.pages.each_with_index do |page, index|
      next if index == 0 # skip header page
      insegnanti.concat(parse_insegnanti_page(page.text))
    end

    import_insegnanti(insegnanti)
    self
  end

  # Parse the compact ANARPE classi format
  # "12AG 1EH -" => [["1","A"], ["2","A"], ["1","G"], ["2","G"], ["1","E"], ["1","H"]]
  def self.parse_classi_compact(text)
    return [] if text.blank?

    result = []
    groups = text.strip.split(/\s+/).reject { |g| g == "-" }

    groups.each do |group|
      digits = group.scan(/\d/)
      letters = group.scan(/[A-Z]/)

      if digits.empty? && letters.any?
        letters.each { |l| result << [l] }
      else
        letters.each do |l|
          digits.each do |d|
            result << [d, l]
          end
        end
      end
    end

    result
  end

  private

  def parse_insegnanti_page(text)
    insegnanti = []
    lines = text.lines.map(&:strip)

    # Find teacher cards: pattern is NAME (all caps with spaces/dots), followed by MATERIA
    i = 0
    while i < lines.size
      line = lines[i]

      # Teacher name: all uppercase letters, spaces, dots, apostrophes - at least 2 words
      if line.match?(/\A[A-Z][A-Z\s.']+\z/) && line.split(/\s+/).size >= 2
        nome_line = line
        # Look ahead for materia and classi
        materia = nil
        classi_text = nil

        # Skip empty lines and look for materia
        j = i + 1
        while j < lines.size && lines[j].blank?
          j += 1
        end

        if j < lines.size && lines[j].match?(/\A[A-Z][A-Z\s]+\z/) && !lines[j].match?(/\d/)
          materia = lines[j]
          j += 1

          # Skip empty lines and look for classi
          while j < lines.size && lines[j].blank?
            j += 1
          end

          if j < lines.size && lines[j].match?(/[A-Z0-9]/)
            classi_text = lines[j]
          end
        end

        if materia
          parts = nome_line.split(/\s+/, 2)
          insegnanti << {
            cognome: parts[0]&.strip,
            nome: parts[1]&.strip,
            materia: materia.strip,
            classi: self.class.parse_classi_compact(classi_text || "")
          }
        end
      end

      i += 1
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

      @imported_count += 1
    rescue => e
      @errors_list << "#{data[:cognome]} #{data[:nome]}: #{e.message}"
    end
  end
end
