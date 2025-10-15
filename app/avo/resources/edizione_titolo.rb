class Avo::Resources::EdizioneTitolo < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :codice_isbn, as: :text
    field :titolo_originale, as: :text
    field :autore, as: :text
  end
end
