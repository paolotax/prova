class IndexComponent < ViewComponent::Base
  # Tell the component filter_params is a helper and not a component method
  delegate :filter_params, to: :helpers

  def call
    form_with(url: url_for, method: :get, class: "px-8 py-6 inline-flex gap-6") do |form|
      concat(
        tag.div(class: "inline-flex gap-4") do
          concat(form.label(:name, "Name"))
          concat(
            form.text_field(
              :name,
              value: filter_params[:name],
              class: "border-b-2 focus:border-slate-400 focus:outline-none"
            )
          )
        end
      )
      concat(
        tag.div(class: "inline-flex gap-4") do
          concat(form.label(:description, "Description"))
          concat(
            form.text_field(
              :description,
              value: filter_params[:description],
              class: "border-b-2 focus:border-slate-400 focus:outline-none"
            )
          )
        end
      )
      concat(
        form.submit
      )
    end
  end
end