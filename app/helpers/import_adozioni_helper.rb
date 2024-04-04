module ImportAdozioniHelper


  def card_classe(import_adozione)
    
    content_tag :div, import_adozione.classe, class: "badge bg-primary"
    
    
  end

  def card_sezione(adozione)  
    tag.div class: [
        "col-span-1 p-2.5 border rounded-md": true,
        "bg-white":   !adozione.mia_adozione?(current_user.miei_editori),
        "bg-yellow-200": adozione.mia_adozione?(current_user.miei_editori)    
      ] do
      link_to new_appunto_path(import_scuola_id: adozione.import_scuola.id, import_adozione_id: adozione.id),
                      data: { turbo_frame: :modal, action: "click->dialog#open"},
                      class: "flex flex-col" do
        content_tag( :div, adozione.classe_e_sezione, class: "text-gray-800 font-semibold" ).html_safe +
        content_tag( :div, adozione.combinazione, class: "text-gray-500 font-semibold text-xs truncate" ).html_safe
      end
    end
  end

end