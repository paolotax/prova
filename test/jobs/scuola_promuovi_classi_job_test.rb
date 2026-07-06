require "test_helper"

class ScuolaPromuoviClassiJobTest < ActiveJob::TestCase
  fixtures :accounts, :scuole, :classi, :adozioni, "miur/adozioni", :persone, :persona_classi, "miur/scuole"

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
