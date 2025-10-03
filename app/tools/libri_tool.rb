class LibriTool < RubyLLM::Tool
  description "Ricerca libri nel database. Rispondi con una tabella di libri con i campi: titolo, codice_isbn, categoria, prezzo, editore"

  param :search, desc: "Ricerca libri"


  def execute(search:, chat: nil)

    user = chat&.user || User.find(1)
    libri = user.libri.includes(:editore).search(search)

    libri.to_json(only: [:titolo, :codice_isbn, :categoria, :disciplina, :note, :prezzo_in_cents], include: { editore: { only: [:editore] } })
  end
end