class Avo::Resources::ImportAdozione < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :CODICESCUOLA, as: :text
    field :ANNOCORSO, as: :text
    field :SEZIONEANNO, as: :text
    field :TIPOGRADOSCUOLA, as: :text
    field :COMBINAZIONE, as: :text
    field :DISCIPLINA, as: :text
    field :CODICEISBN, as: :text
    field :AUTORI, as: :text
    field :TITOLO, as: :text
    field :SOTTOTITOLO, as: :text
    field :VOLUME, as: :text
    field :EDITORE, as: :text
    field :PREZZO, as: :text
    field :NUOVAADOZ, as: :text
    field :DAACQUIST, as: :text
    field :CONSIGLIATO, as: :text
    field :anno_scolastico, as: :text
    field :import_scuola, as: :belongs_to
  end
end
