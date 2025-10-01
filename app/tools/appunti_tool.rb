class AppuntiTool < RubyLLM::Tool
  description "Tool per trovare appunti nel database"

  param :search, desc: "Cerca un appunto"

  def execute(search:)
    appunti = User.find(1).appunti.includes(:import_scuola).search_all_word(search)
    
    appunti.to_json(only: [:nome, :body, :email, :telefono, :stato], include: { import_scuola: { only: [:DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE] } })
  end
end