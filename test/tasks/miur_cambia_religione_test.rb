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

  private

  def esegui_task
    Rake::Task["miur:cambia_religione"].reenable
    Rake::Task["miur:cambia_religione"].invoke
  end
end
