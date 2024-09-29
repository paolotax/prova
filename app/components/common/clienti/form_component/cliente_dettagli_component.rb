module Common
  class Clienti::FormComponent::ClienteDettagliComponent < Common::MultistepFormComponent::StepComponent
    class << self
      def title = "Dettagli Cliente"

      def input_attributes = %i[denominazione partita_iva]

      
    end

    def call
      tag.div(**wrapper_attributes) do
        concat(
          tag.div(class: "flex flex-col gap-2 text-right text-xs text-gray-400") do
            "#{form.object.current_step}:current_step   #{form.object.latest_step}:latest_step"
          end
        ) if Rails.env.development?
        concat(
            tag.div(class: "w-full flex flex-col gap-2") do
              concat(form.label(:denominazione, "Ragione Sociale", class: "text-sm"))
              concat(form.text_field(:denominazione, class: "
                w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
              "))
              form.object.errors.full_messages_for(:denominazione).each do |m|
                concat(tag.p(m, class: "text-sm text-red-500"))
              end
            end
        )
        concat(
          tag.div(class: "w-full mt-5 flex flex-row gap-2") do

            concat(
              tag.div(class: "w-5/6 flex flex-col gap-2") do
                concat(form.label(:indirizzo, "Indirizzo", class: "text-sm"))
                concat(form.text_field(:indirizzo, class: "
                  w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
                "))
                form.object.errors.full_messages_for(:indirizzo).each do |m|
                  concat(tag.p(m, class: "text-sm text-red-500"))
                end
              end
            )
            concat(
              tag.div(class: "w-1/6 flex flex-col gap-2") do
                concat(form.label(:numero_civico, "Civico", class: "text-sm"))
                concat(form.text_field(:numero_civico, class: "
                  w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
                "))
                form.object.errors.full_messages_for(:numero_civico).each do |m|
                  concat(tag.p(m, class: "text-sm text-red-500"))
                end
              end
            )
          end
        )
        concat(
          tag.div(class: "w-full mt-5 flex flex-row gap-2") do

            concat(
              tag.div(class: "w-1/6 flex flex-col gap-2") do
                concat(form.label(:cap, "CAP", class: "text-sm"))
                concat(form.text_field(:cap, class: "
                  w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
                "))
                form.object.errors.full_messages_for(:cap).each do |m|
                  concat(tag.p(m, class: "text-sm text-red-500"))
                end
              end
            )
            concat(
              tag.div(class: "w-4/6 flex flex-col gap-2") do
                concat(form.label(:comune, "Comune", class: "text-sm"))
                concat(form.text_field(:comune, class: "
                  w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
                "))
                form.object.errors.full_messages_for(:comune).each do |m|
                  concat(tag.p(m, class: "text-sm text-red-500"))
                end
              end
            )
            concat(
              tag.div(class: "w-1/6 flex flex-col gap-2") do
                concat(form.label(:provincia, "Provincia", class: "text-sm"))
                concat(form.text_field(:provincia, class: "
                  w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
                "))
                form.object.errors.full_messages_for(:provincia).each do |m|
                  concat(tag.p(m, class: "text-sm text-red-500"))
                end
              end
            )
          end
        )

        concat(
          tag.div(class: "w-full mt-5 flex flex-row gap-2") do
            concat(
              tag.div(class: "w-1/2 flex flex-col gap-2") do
                concat(form.label(:partita_iva, "Partita IVA", class: "text-sm"))
                concat(form.text_field(:partita_iva, class: "
                  w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
                "))
                form.object.errors.full_messages_for(:partita_iva).each do |m|
                  concat(tag.p(m, class: "text-sm text-red-500"))
                end
              end
            )
            concat(
              tag.div(class: "w-1/2 flex flex-col gap-2") do
                concat(form.label(:codice_fiscale, "Codice Fiscale", class: "text-sm"))
                concat(form.text_field(:codice_fiscale, class: "
                  w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
                "))
                form.object.errors.full_messages_for(:codice_fiscale).each do |m|
                  concat(tag.p(m, class: "text-sm text-red-500"))
                end
              end
            )
          end
        )
        concat(
          tag.div(class: "mt-5 w-1/2 pr-1 flex flex-col gap-2") do
            concat(form.label(:indirizzo_telematico, "Codice SDI", class: "text-sm"))
            concat(form.text_field(:indirizzo_telematico, class: "
              w-full px-2 py-1 outline-none border-b-2 border-zinc-300 hover:border-slate-500 focus:border-slate-500
            "))
            form.object.errors.full_messages_for(:indirizzo_telematico).each do |m|
              concat(tag.p(m, class: "text-sm text-red-500"))
            end
          end
        )
      end
    end

  end
end