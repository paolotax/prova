# Le righe sopravvivono alla cascata del documento (muore il join
# documento_righe, non la riga) e il loro FK su libri blocca la destroy dei
# libri nelle cancellazioni admin. Prima della cascata vanno eliminate le
# righe che puntano ai libri morenti, tranne quelle usate da documenti che
# sopravvivono (lì il FK deve continuare a proteggere).
module PurgaRigheOrfane
  private

    def purga_righe(libri, documenti_morenti)
      righe = Riga.where(libro_id: libri.select(:id))
      righe_altrui = DocumentoRiga.where(riga_id: righe.select(:id))
                                  .where.not(documento_id: documenti_morenti.select(:id))
                                  .select(:riga_id)
      purgabili_ids = righe.where.not(id: righe_altrui).pluck(:id)
      return if purgabili_ids.empty?

      join = DocumentoRiga.where(riga_id: purgabili_ids)
      ConsegnaRiga.where(documento_riga_id: join.select(:id)).delete_all
      join.delete_all
      Riga.where(id: purgabili_ids).delete_all
    end
end
