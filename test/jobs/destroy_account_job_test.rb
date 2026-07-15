require "test_helper"

class DestroyAccountJobTest < ActiveJob::TestCase
  fixtures :accounts, :users, :memberships

  test "elimina un account con adozioni collegate ai libri (ordine cascata libri/adozioni)" do
    account = Account.create!(name: "Da Eliminare")
    categoria = account.categorie.create!(nome_categoria: "Cascata")
    libro = account.libri.create!(titolo: "Libro Cascata", codice_isbn: "9880000000999",
                                  prezzo_in_cents: 1000, user: users(:one), categoria: categoria)
    scuola = account.scuole.create!(denominazione: "Scuola Cascata",
                                    codice_ministeriale: "ZZEE00001X", provincia: "ZZ")
    classe = account.classi.create!(scuola: scuola, anno_corso: "1", sezione: "A",
                                    anno_scolastico: "202627", stato: "attiva")
    classe.adozioni.create!(account: account, libro: libro, codice_isbn: libro.codice_isbn,
                            anno_scolastico: "202627")

    DestroyAccountJob.perform_now(account.id)

    assert_not Account.exists?(account.id), "l'account viene eliminato"
    assert_not Libro.exists?(libro.id), "il libro collegato all'adozione viene eliminato"
  end
end
