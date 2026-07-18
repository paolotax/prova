require "test_helper"
require "rake"

# Copre il task miur:cambia_religione: normalizza a daacquist = "No" le adozioni
# EE di religione/alternativa (annocorso 2/3/5) cosi' non contano nel tetto di spesa.
# La grafia MIUR reale "RELIGIONE CATTOLICA/ATTIVITA' ALTERNATIVA" (174k righe) era
# scoperta dall'elenco disciplina.
class MiurCambiaReligioneTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("miur:cambia_religione")
    Miur.stubs(:anno_corrente).returns("202627")
  end

  test "cambia_religione copre la grafia RELIGIONE CATTOLICA/ATTIVITA' ALTERNATIVA" do
    righe = ["2", "3", "5"].map.with_index do |annocorso, i|
      Miur::Adozione.create!(
        anno_scolastico: "202627",
        tipogradoscuola: "EE",
        annocorso: annocorso,
        disciplina: "RELIGIONE CATTOLICA/ATTIVITA' ALTERNATIVA",
        daacquist: "Si",
        codicescuola: "MITEST000#{i}",
        codiceisbn: "978000000000#{i}"
      )
    end

    esegui_task

    righe.each do |riga|
      assert_equal "No", riga.reload.daacquist,
        "attesa normalizzazione a 'No' per annocorso #{riga.annocorso}"
    end
  end

  test "religione_ee_da_normalizzare esclude gli anni d'acquisto (1/4) e i non-EE" do
    fuori_scope = [
      { annocorso: "1", tipogradoscuola: "EE" },  # anno d'acquisto vol. 1-2-3
      { annocorso: "4", tipogradoscuola: "EE" },  # anno d'acquisto vol. 4-5
      { annocorso: "2", tipogradoscuola: "MM" },  # non elementari
    ].map.with_index do |attrs, i|
      Miur::Adozione.create!(
        anno_scolastico: "202627",
        disciplina: "RELIGIONE",
        daacquist: "Si",
        codicescuola: "MITEST100#{i}",
        codiceisbn: "978000000010#{i}",
        **attrs
      )
    end
    dentro = Miur::Adozione.create!(
      anno_scolastico: "202627", tipogradoscuola: "EE", annocorso: "2",
      disciplina: "RELIGIONE", daacquist: "Si",
      codicescuola: "MITEST2000", codiceisbn: "9780000002000"
    )

    esegui_task

    fuori_scope.each do |riga|
      assert_equal "Si", riga.reload.daacquist,
        "annocorso #{riga.annocorso}/#{riga.tipogradoscuola} non va normalizzato"
    end
    assert_equal "No", dentro.reload.daacquist
  end

  private

  def esegui_task
    Rake::Task["miur:cambia_religione"].reenable
    Rake::Task["miur:cambia_religione"].invoke
  end
end
