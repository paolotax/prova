class CreateMultiLevelDocumentHierarchy < ActiveRecord::Migration[8.0]
  def up
    say "Creazione gerarchia multi-livello per documenti..."

    # Reset tutte le relazioni esistenti tranne quelle di livello 1 (figli diretti di TD01/TD04)
    # Manterremo TD01 come radice, ma riorganizzeremo i suoi figli

    # Step 1: Identifica tutti i documenti TD01/TD04 che sono padri
    td_docs = Documento.joins(:causale)
      .where(causali: { causale: ['TD01', 'TD04', 'TD24'] })
      .where(id: Documento.select(:documento_padre_id).distinct)

    say "Trovati #{td_docs.count} documenti TD radice con figli"

    # Step 2: Per ogni TD radice, analizza i figli e crea gerarchie intermedie
    td_docs.each do |td_root|
      say ""
      say "Analisi TD #{td_root.causale.causale} ##{td_root.id}:"

      # Ottieni tutti i figli diretti (DDT e Ordini)
      figli = td_root.documenti_derivati.includes(:causale)

      say "  - #{figli.count} figli diretti"

      # Separa DDT da Ordini
      ddt_figli = figli.select { |f| ['Documento di trasporto', 'DDT Fornitore'].include?(f.causale&.causale) }
      ordini_figli = figli.select { |f| ['Ordine Scuola', 'Ordine Cliente'].include?(f.causale&.causale) }
      altri_figli = figli - ddt_figli - ordini_figli

      say "    * #{ddt_figli.count} DDT"
      say "    * #{ordini_figli.count} Ordini"
      say "    * #{altri_figli.count} Altri" if altri_figli.any?

      # Step 3: Per ogni DDT, verifica quali ordini condividono righe
      ddt_figli.each do |ddt|
        riga_ids_ddt = ddt.righe.pluck(:id)

        next if riga_ids_ddt.empty?

        # Trova ordini che condividono righe con questo DDT
        ordini_correlati = ordini_figli.select do |ordine|
          riga_ids_ordine = ordine.righe.pluck(:id)
          # Verifica se c'è intersezione tra le righe
          (riga_ids_ddt & riga_ids_ordine).any?
        end

        if ordini_correlati.any?
          say "    → DDT ##{ddt.id} condivide righe con #{ordini_correlati.count} ordini"

          # Sposta gli ordini come figli del DDT invece che del TD
          ordini_correlati.each do |ordine|
            if ordine.documento_padre_id == td_root.id
              ordine.update_columns(
                documento_padre_id: ddt.id,
                derivato_da_causale_id: ddt.causale_id
              )
              say "      * Ordine ##{ordine.id} (#{ordine.numero_documento}) → figlio di DDT ##{ddt.id}"
            end
          end
        end
      end
    end

    # Statistiche finali
    say ""
    say "Statistiche finali:"

    # Conta documenti per livello
    livello_0 = Documento.where(documento_padre_id: nil).count
    livello_1 = Documento.where.not(documento_padre_id: nil)
                        .where(documento_padre_id: Documento.where(documento_padre_id: nil).select(:id))
                        .count
    livello_2 = Documento.where.not(documento_padre_id: nil)
                        .where.not(documento_padre_id: Documento.where(documento_padre_id: nil).select(:id))
                        .count

    say "  - Livello 0 (radici): #{livello_0}"
    say "  - Livello 1 (figli diretti radici): #{livello_1}"
    say "  - Livello 2+ (nipoti): #{livello_2}"

    # Mostra alcuni esempi di gerarchie complete
    say ""
    say "Esempi di gerarchie complete:"

    Documento.joins(:causale)
      .where(causali: { causale: 'TD01' })
      .where(documento_padre_id: nil)
      .limit(3)
      .each do |td|
        figli_count = td.documenti_derivati.count
        nipoti_count = td.documenti_derivati.sum { |f| f.documenti_derivati.count }

        say "  TD01 ##{td.id}: #{figli_count} figli, #{nipoti_count} nipoti"

        td.documenti_derivati.includes(:causale, :documenti_derivati).each do |figlio|
          if figlio.documenti_derivati.any?
            say "    └─ #{figlio.causale&.causale} ##{figlio.id} → #{figlio.documenti_derivati.count} sotto-figli"
          end
        end
      end
  end

  def down
    say "Appiattimento gerarchia a singolo livello..."

    # Trova tutti i documenti che sono nipoti (hanno un nonno)
    # e spostali come figli diretti del nonno

    nipoti = Documento.where.not(documento_padre_id: nil)
      .where(documento_padre_id: Documento.where.not(documento_padre_id: nil).select(:id))

    say "Trovati #{nipoti.count} documenti nipoti da riportare a livello 1"

    nipoti.each do |nipote|
      padre = nipote.documento_padre
      next unless padre

      nonno = padre.documento_padre
      next unless nonno

      # Sposta il nipote come figlio diretto del nonno
      nipote.update_columns(
        documento_padre_id: nonno.id,
        derivato_da_causale_id: nonno.causale_id
      )
    end

    say "✓ Gerarchia appiattita"
  end
end
