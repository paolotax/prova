require "test_helper"
require "turbo/broadcastable/test_helper"

class ScuolaPromuoviClassiJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  fixtures :accounts, :scuole, :classi, :adozioni, "miur/adozioni", :persone, :persona_classi, "miur/scuole"

  test "rinfresca gli aggregati del controllo adozioni dopo la promozione" do
    scuola = scuole(:primaria_attiva)
    account = scuola.account
    # Gli aggregati (step, card riepilogo, tabella province) sono server-rendered:
    # si aggiornano solo con un morph-refresh sul canale a cui la pagina si iscrive.
    streams = capture_turbo_stream_broadcasts([account, "controllo_adozioni_riepilogo", "_all"]) do
      ScuolaPromuoviClassiJob.perform_now(scuola, da: "202526", a: "202627")
    end
    assert streams.any? { |s| s["action"] == "refresh" },
      "attesa una turbo-stream refresh sul canale riepilogo _all per rinfrescare gli aggregati"
  end

  test "promuove la scuola all'anno target" do
    scuola = scuole(:primaria_attiva)
    ScuolaPromuoviClassiJob.perform_now(scuola, da: "202526", a: "202627")
    assert scuola.reload.classi.attive.per_anno("202627").exists?
  end

  test "inoltra la mappa spostamenti insegnanti" do
    scuola = scuole(:primaria_attiva)
    # promuovo una prima volta per creare le nuove prime
    ScuolaPromuoviClassiJob.perform_now(scuola, da: "202526", a: "202627")
    nuova_prima = scuola.classi.attive.find_by(anno_corso: "1", sezione: "A", anno_scolastico: "202627")
    pc = persona_classi(:maestra_quinta)
    assert_difference -> { PersonaClasse.where(classe_id: nuova_prima.id).count }, 1 do
      ScuolaPromuoviClassiJob.perform_now(scuola, da: "202526", a: "202627",
                                          spostamenti_insegnanti: { pc.id => "A" })
    end
  end
end
