class Avo::Resources::Editore < Avo::BaseResource
  
  # self.includes = []
  # self.attachments = []
  
  self.search = {
    query: -> { 
      query.ransack(
        id_eq: params[:q], 
        editore_cont: params[:q],
        gruppo_cont: params[:q],
        m: "or").result(distinct: false) 
      },
    item: -> do
      {
        title: "[#{record.id}] #{record.editore}"
      }
    end
  }

  def fields
    field :id, as: :id
    field :editore, 
      as: :text, 
      sortable: true
    field :gruppo, 
      as: :text, 
      sortable: true
  end
end
