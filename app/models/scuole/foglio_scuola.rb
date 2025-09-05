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

    # Optimized: Only include necessary associations for classi
    def classi
      @classi ||= scuola.classi.includes(:import_adozioni)  
    end

    def mie_tappe
      @mie_tappe ||= user.tappe.includes(:giri).where(tappable_id: scuola.id) 
    end

    # Keep the full association for when we need the actual records
    def import_adozioni
      @import_adozioni ||= scuola.import_adozioni.includes(:classe, :libro, :import_scuola, :saggi, :seguiti, :kit)
    end

    # Optimized: Group by classe to avoid N+1 queries in the view
    def mie_adozioni_by_classe
      @mie_adozioni_by_classe ||= user.mie_adozioni
                                      .includes(:classe, :libro, :import_scuola, :saggi, :seguiti, :kit)
                                      .where(CODICESCUOLA: scuola.CODICESCUOLA)
                                      .group_by(&:classe)
    end

    # Keep the original method for compatibility
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

    def ssk
      @ssk ||= scuola.appunti.ssk.dell_utente(user).includes(:import_scuola, :user)
    end

  
  end
end
