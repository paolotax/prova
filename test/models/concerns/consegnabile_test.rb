require "test_helper"

class ConsegnabileTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti,
           :libri, :categorie, :editori, :righe, :documento_righe

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
    @documento = documenti(:fattura_uno) # 1 riga da 20 copie
    @documento_riga = documento_righe(:dr_fattura_uno)
  end

  teardown do
    Current.reset
  end

  test "mark_consegnato consegna tutti i residui in un colpo" do
    @documento.mark_consegnato

    assert @documento.consegnato?
    assert_not @documento.parzialmente_consegnato?
    assert_equal 1, @documento.consegne.count
    assert_equal 20, @documento.consegne.first.consegna_righe.sum(:quantita)
    assert_equal 0, @documento.copie_residue_da_consegnare
  end

  test "mark_consegnato è idempotente" do
    @documento.mark_consegnato
    assert_no_difference -> { Consegna.count } do
      @documento.mark_consegnato
    end
  end

  test "consegna_parziale! lascia il residuo e lo stato parziale" do
    @documento.consegna_parziale!({ @documento_riga.id => 12 })

    assert_not @documento.consegnato?
    assert @documento.parzialmente_consegnato?
    assert_equal 8, @documento.copie_residue_da_consegnare
    assert_equal({ @documento_riga.id => 8 }, @documento.residui_per_documento_riga)
  end

  test "due consegne parziali saturano il documento" do
    @documento.consegna_parziale!({ @documento_riga.id => 12 })
    @documento.consegna_parziale!({ @documento_riga.id => 8 })

    assert @documento.consegnato?
    assert_equal 2, @documento.consegne.count
  end

  test "consegna_parziale! oltre il residuo solleva ArgumentError" do
    @documento.consegna_parziale!({ @documento_riga.id => 12 })

    assert_raises(ArgumentError) do
      @documento.consegna_parziale!({ @documento_riga.id => 9 })
    end
  end

  test "consegna_parziale! senza quantità positive solleva ArgumentError" do
    assert_raises(ArgumentError) do
      @documento.consegna_parziale!({ @documento_riga.id => 0 })
    end
  end

  test "unmark_consegnato distrugge una consegna specifica e i residui riaumentano" do
    prima = @documento.consegna_parziale!({ @documento_riga.id => 12 })
    @documento.consegna_parziale!({ @documento_riga.id => 8 })

    @documento.unmark_consegnato(prima)

    assert_not @documento.consegnato?
    assert_equal 12, @documento.copie_residue_da_consegnare
  end

  test "unmark_consegnato senza argomento toglie l'ultima consegna" do
    @documento.mark_consegnato
    @documento.unmark_consegnato

    assert_not @documento.consegnato?
    assert_equal 0, @documento.consegne.count
  end

  test "consegnato_il è la data dell'ultima consegna" do
    @documento.consegna_parziale!({ @documento_riga.id => 12 }, consegnato_il: 3.days.ago)
    @documento.consegna_parziale!({ @documento_riga.id => 8 }, consegnato_il: 1.day.ago)

    assert_in_delta 1.day.ago.to_f, @documento.consegnato_il.to_f, 5
  end

  test "documento senza consegne non è consegnato" do
    assert_not @documento.consegnato?
    assert_not @documento.parzialmente_consegnato?
    assert_nil @documento.consegnato_il
  end

  test "mark_consegnato su documento senza righe crea la consegna vuota" do
    doc = Documento.create!(account: accounts(:fizzy), user: users(:one),
                            causale: causali(:fattura), clientable: clienti(:cliente_fizzy),
                            numero_documento: 999, data_documento: Date.today)
    doc.mark_consegnato
    assert doc.consegnato?
  end

  test "mark_consegnato solleva ArgumentError su documento non consegnabile" do
    documento = documenti(:ddt_fornitore_fizzy) # causale: carico_fornitore (gestione_consegna: false)

    assert_raises(ArgumentError) do
      documento.mark_consegnato
    end
    assert_equal 0, documento.consegne.count
  end

  test "consegna_parziale! solleva ArgumentError su documento non consegnabile" do
    documento = documenti(:ddt_fornitore_fizzy) # causale: carico_fornitore (gestione_consegna: false)

    assert_raises(ArgumentError) do
      documento.consegna_parziale!({ documento_righe(:dr_fattura_uno).id => 1 })
    end
    assert_equal 0, documento.consegne.count
  end
end
