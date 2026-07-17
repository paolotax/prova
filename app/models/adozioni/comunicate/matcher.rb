module Adozioni
  module Comunicate
    class Matcher
      def self.rimatch!(account:, anno_scolastico:)
        Comunicata.for_account(account).per_anno(anno_scolastico).find_each do |comunicata|
          new(comunicata).match!
        end
      end

      def initialize(comunicata)
        @comunicata = comunicata
      end

      def match!
        adozione = trova_adozione

        if adozione.nil?
          @comunicata.update!(stato_match: "adozione_non_trovata", adozione: nil, classe: nil)
        elsif @comunicata.multi_sezione?
          match_multi_sezione(adozione)
        else
          match_mono_sezione(adozione)
        end
      end

      # Distribuzione forzata dalla UI: sovrascrive numero_alunni esistenti.
      def distribuisci!
        adozione = @comunicata.adozione || trova_adozione
        return false unless adozione

        classi = @comunicata.sezioni_lista.map { |sezione| trova_classe(adozione, sezione) }
        return false unless classi.all?

        distribuisci_su(classi)
        @comunicata.update!(stato_match: "multi_sezione_distribuita", adozione: adozione)
        true
      end

      private

      def trova_adozione
        Adozione.where(
          account_id: @comunicata.account_id,
          anno_scolastico: @comunicata.anno_scolastico,
          codicescuola: @comunicata.codicescuola,
          codice_isbn: @comunicata.ean,
          anno_corso: @comunicata.anno_corso
        ).first
      end

      def match_mono_sezione(adozione)
        classe = trova_classe(adozione, @comunicata.sezioni_lista.first)

        if classe
          @comunicata.update!(stato_match: "matched", adozione: adozione, classe: classe)
          classe.update!(numero_alunni: @comunicata.alunni)
        else
          @comunicata.update!(stato_match: "classe_non_trovata", adozione: adozione, classe: nil)
        end
      end

      def match_multi_sezione(adozione)
        classi = @comunicata.sezioni_lista.map { |sezione| trova_classe(adozione, sezione) }

        if classi.all? && classi.none? { |classe| classe.numero_alunni.present? }
          distribuisci_su(classi)
          @comunicata.update!(stato_match: "multi_sezione_distribuita", adozione: adozione, classe: nil)
        else
          @comunicata.update!(stato_match: "multi_sezione", adozione: adozione, classe: nil)
        end
      end

      def trova_classe(adozione, sezione)
        return nil if sezione.blank?

        if adozione.classe.sezione == sezione && adozione.classe.anno_corso == @comunicata.anno_corso
          return adozione.classe
        end

        Classe.attive.find_by(
          scuola_id: adozione.classe.scuola_id,
          anno_corso: @comunicata.anno_corso,
          sezione: sezione
        )
      end

      def distribuisci_su(classi)
        base, resto = @comunicata.alunni.divmod(classi.size)
        classi.each_with_index do |classe, indice|
          classe.update!(numero_alunni: base + (indice < resto ? 1 : 0))
        end
      end
    end
  end
end
