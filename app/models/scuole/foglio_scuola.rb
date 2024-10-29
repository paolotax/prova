module Scuole
  class FoglioScuola
    include ActiveModel::Model

    attr_accessor :scuola, :user

    def initialize(scuola:)
      @scuola = scuola
    end

    def user
      Current.user
    end

    def classi
      @classi ||= scuola.classi.includes(:import_adozioni, :import_scuola, :adozioni, :appunti, :vendita, :omaggio, :adozione)  
    end

    def mie_tappe
      @mie_tappe ||=  user.tappe.includes(:giro).where(tappable_id: scuola.id) 
    end

    def adozioni
      @adozioni ||= user.adozioni.joins(:scuola).where("import_scuole.id = ?", scuola.id)
    end

    def import_adozioni
      @import_adozioni ||= scuola.import_adozioni.includes(:classe, :libro, :import_scuola, :saggi, :seguiti, :kit)
    end

    def miei_editori
      @miei_editori ||= user.miei_editori
    end

    def mie_adozioni
      @mie_adozioni ||= user.mie_adozioni
                          .includes(:classe, :libro, :import_scuola, :saggi, :seguiti, :kit)
                          .where(CODICESCUOLA: scuola.CODICESCUOLA)
    end

    def appunti_non_archiviati
      @appunti_non_archiviati ||= scuola.appunti.non_archiviati.non_saggi.dell_utente(user)
    end

    def appunti_archiviati
      @appunti_archiviati ||= scuola.appunti.archiviati.non_saggi.dell_utente(user)
    end

    def documenti
      @documenti ||= scuola.documenti.where(user_id: user).includes(:causale, :righe, documento_righe: [riga: :libro])
    end

    def righe
      @righe ||= scuola.righe
    end

    def ssk
      @ssk ||= scuola.appunti.ssk.dell_utente(user)
    end
  
  end
end
