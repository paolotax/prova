class LibriTool < RubyLLM::Tool
  description "Tool for managing libri"

  param :search, desc: "Search for a libro"

  def execute(search:)
    libri = User.find(1).libri.search_all_word(search)

    libri.to_json(only: [:titolo, :codice_isbn, :categoria, :disciplina, :note, :prezzo_in_cents])
  end
end