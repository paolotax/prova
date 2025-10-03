class LibriSchema < RubyLLM::Schema
  
  array :libri do
    object do
      string :titolo, description: "titolo del libro"
      string :codice_isbn, description: "codice isbn del libro"
      string :disciplina, description: "disciplina del libro"
      string :categoria, description: "categoria del libro"

      object :editore do
        string :editore, description: "editore del libro"
      end
    end
  end 

end