require "test_helper"

class UpdateMieAdozioniJobTest < ActiveJob::TestCase
  fixtures :accounts, :users, :memberships, :editori, :mandati, :scuole, :classi, :adozioni

  setup do
    @fizzy = accounts(:fizzy)
  end

  test "sets mia=true for adozioni matching mandato editore" do
    # fizzy has mandato for Zanichelli (no provincia/grado filter = covers all)
    # adozione_italiano_1a has editore: "Zanichelli"
    UpdateMieAdozioniJob.perform_now(@fizzy)

    adozione_zanichelli = adozioni(:adozione_italiano_1a)
    adozione_pearson = adozioni(:adozione_matematica_1a)

    adozione_zanichelli.reload
    adozione_pearson.reload

    assert adozione_zanichelli.mia?, "Zanichelli adoption should be mia"
    assert_not adozione_pearson.mia?, "Pearson adoption should not be mia"
  end

  test "resets mia=false before applying" do
    adozione = adozioni(:adozione_matematica_1a)
    adozione.update_column(:mia, true)

    UpdateMieAdozioniJob.perform_now(@fizzy)

    adozione.reload
    assert_not adozione.mia?, "Pearson adoption should be reset to not mia"
  end

  test "respects provincia filter on mandato" do
    acme = accounts(:acme)
    # acme has mandato for Zanichelli with provincia: "RM", grado: "N"
    # scuola_acme is in RM with grado N
    UpdateMieAdozioniJob.perform_now(acme)

    adozione_rm = adozioni(:adozione_fisica_acme)
    adozione_rm.reload

    assert adozione_rm.mia?, "Zanichelli adoption in RM should be mia"
  end

  test "mandato with area only matches schools in that area" do
    UpdateMieAdozioniJob.perform_now(@fizzy)

    assert adozioni(:adozione_nord_pearson).reload.mia?,
      "Pearson adoption in Nord area should be mia"
    assert_not adozioni(:adozione_sud_pearson).reload.mia?,
      "Pearson adoption in Sud area should NOT be mia"
  end

  test "mandato without area matches all schools in provincia" do
    UpdateMieAdozioniJob.perform_now(@fizzy)

    assert adozioni(:adozione_italiano_1a).reload.mia?,
      "Zanichelli adoption should be mia (mandato without area)"
  end
end
