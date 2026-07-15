require "test_helper"

# Silenzia il broadcast (renderizza un partial, fuori scope qui).
class CountScuolePerZonaJobSilent < CountScuolePerZonaJob
  private
  def broadcast_zone_update(_zona) = nil
end

class CountScuolePerZonaJobTest < ActiveJob::TestCase
  fixtures :accounts, :users, :memberships

  ANNO = "202627"

  setup do
    @account = accounts(:fizzy)
    TipoScuola.find_by(tipo: "SCUOLA PRIMARIA") ||
      TipoScuola.new(tipo: "SCUOLA PRIMARIA", grado: "E").tap { |t| t.save!(validate: false) }
    @zona = @account.zone.create!(provincia: "XX", grado: "E", regione: "TESTLANDIA",
                                  stato: "conteggio")
    Miur::Scuola.create!(codice_scuola: "XXEE00099B", anno_scolastico: ANNO, provincia: "XX",
      comune: "TESTVILLE", denominazione: "PRIMARIA NUOVA", tipo_scuola: "SCUOLA PRIMARIA")
    # La direzione NON conta: tipo fuori dal grado E.
    Miur::Scuola.create!(codice_scuola: "XXIC00100X", anno_scolastico: ANNO, provincia: "XX",
      comune: "TESTVILLE", denominazione: "IC TESTVILLE", tipo_scuola: "ISTITUTO COMPRENSIVO")
  end

  test "conta le scuole ministeriali (anno corrente) di provincia+grado e marca pronta" do
    CountScuolePerZonaJobSilent.perform_now(@zona)

    assert_equal 1, @zona.reload.scuole_count
    assert_equal "pronta", @zona.stato
  end
end
