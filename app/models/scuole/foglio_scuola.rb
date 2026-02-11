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

    # def mie_tappe
    #   #@mie_tappe ||= user.tappe.includes(:giri).where(tappable_id: scuola.id) 
    # end

    def import_adozioni
      @import_adozioni ||= scuola.import_scuola&.import_adozioni&.includes(:classe, :libro, :import_scuola) || ImportAdozione.none
    end

    # Optimized: Group by classe to avoid N+1 queries in the view
    def mie_adozioni_by_classe
      @mie_adozioni_by_classe ||= user.import_adozioni.mie_adozioni
                                      .select('import_adozioni.*')
                                      .includes(:classe, :libro, :import_scuola)
                                      .where(CODICESCUOLA: scuola.codice_ministeriale)
                                      .group_by(&:classe)
    end

    def mie_adozioni
      @mie_adozioni ||= user.import_adozioni.mie_adozioni
                          .select('import_adozioni.*')
                          .includes(:classe, :libro, :import_scuola)
                          .where(CODICESCUOLA: scuola.codice_ministeriale)
    end

    def appunti_non_archiviati
      @appunti_non_archiviati ||= scuola.appunti.non_archiviati
    end

    def appunti_archiviati
      @appunti_archiviati ||= scuola.appunti.where(stato: 'archiviato')
    end

    def documenti
      @documenti ||= scuola.documenti.where(user_id: user).includes(:causale, :righe, documento_righe: [riga: :libro])
    end

    def ssk
      @ssk ||= ConsegnaSaggio.joins(adozione: :classe)
                              .where(classi: { codice_ministeriale_origine: scuola.codice_ministeriale })
                              .where(consegne_saggio: { account_id: Current.account&.id })
    end

  
  end
end
