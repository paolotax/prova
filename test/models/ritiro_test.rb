require "test_helper"

class RitiroTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :editori, :categorie, :libri, :scuole,
           :collane, :bolle_visione, :bolla_visione_righe, :causali

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @ritiro = Ritiro.new(@scuola)
  end

  test "bolle ritorna le bolle con almeno una riga aperta o rientrata" do
    assert_includes @ritiro.bolle, bolla_visione_righe(:aperta).bolla_visione
  end

  test "bolle non include bolle con tutte le righe processate (saggio/venduto/mancante)" do
    bv = bolla_visione_righe(:chiusa_in_saggio).bolla_visione
    bv.bolla_visione_righe.update_all(esito: BollaVisioneRiga.esiti[:in_saggio], processato_at: Time.current)
    refute_includes Ritiro.new(@scuola).bolle, bv
  end

  test "righe(bolla) ritorna le righe visibili (aperte + rientrate)" do
    bv = bolla_visione_righe(:aperta).bolla_visione
    righe = @ritiro.righe(bv)
    assert righe.any?
    assert(righe.all? { |r| r.processato_at.nil? || r.rientrato? })
  end

  test "gruppo_per(libro_id, collana_id) ritorna il gruppo da CollanaLibro" do
    riga = bolla_visione_righe(:aperta)
    bolla = riga.bolla_visione
    CollanaLibro.find_or_create_by!(account: accounts(:fizzy), collana: bolla.collana, libro: riga.libro) do |cl|
      cl.gruppo = "Gruppo A"
    end
    assert_equal "Gruppo A", Ritiro.new(@scuola).gruppo_per(riga.libro_id, bolla.collana_id)
  end

  test "gruppo_per ritorna nil se non c'è CollanaLibro" do
    riga = bolla_visione_righe(:aperta)
    bolla = riga.bolla_visione
    CollanaLibro.where(collana: bolla.collana, libro: riga.libro).destroy_all
    assert_nil Ritiro.new(@scuola).gruppo_per(riga.libro_id, bolla.collana_id)
  end

  test "empty? true quando non ci sono bolle" do
    @scuola.bolle_visione.destroy_all
    assert Ritiro.new(@scuola).empty?
  end

  # --- crea_documento -------------------------------------------------------

  test "crea_documento crea documento con causale, clientable e righe; chiude bolle_visione_righe" do
    riga1 = bolla_visione_righe(:aperta)
    riga2 = bolla_visione_righe(:aperta_due)

    documento = @ritiro.crea_documento(
      righe: [riga1, riga2],
      causale: causali(:scarico_saggi),
      clientable: @scuola,
      data: Date.current
    )

    assert_equal causali(:scarico_saggi), documento.causale
    assert_equal @scuola, documento.clientable
    assert_equal 2, documento.documento_righe.count

    riga1.reload
    assert_equal "in_saggio", riga1.esito
    assert_not_nil riga1.processato_at
    assert_includes documento.documento_righe.map { |dr| dr.riga.libro_id }, riga1.libro_id
  end

  test "crea_documento raises ArgumentError quando causale è nil; nessun documento creato" do
    riga = bolla_visione_righe(:aperta)
    assert_no_difference "Documento.count" do
      assert_raises ArgumentError do
        @ritiro.crea_documento(righe: [riga], causale: nil, clientable: @scuola, data: Date.current)
      end
    end
    riga.reload
    assert_nil riga.processato_at
  end

  test "crea_documento collega ogni documento_riga alla bolla_visione_riga di provenienza" do
    riga1 = bolla_visione_righe(:aperta)
    riga2 = bolla_visione_righe(:aperta_due)

    documento = @ritiro.crea_documento(
      righe: [riga1, riga2],
      causale: causali(:scarico_saggi),
      clientable: @scuola,
      data: Date.current
    )

    [riga1, riga2].each do |bv_riga|
      bv_riga.reload
      assert_not_nil bv_riga.documento_riga, "bv_riga #{bv_riga.id} senza documento_riga"
      assert_equal documento, bv_riga.documento_riga.documento
      assert_equal bv_riga.libro_id, bv_riga.documento_riga.riga.libro_id
    end
  end

  # --- rollback bv_riga al delete ------------------------------------------

  test "destroy documento marca le bv_riga collegate come rientrate (esito: rientrato, documento_riga_id: nil)" do
    riga1 = bolla_visione_righe(:aperta)
    riga2 = bolla_visione_righe(:aperta_due)

    documento = @ritiro.crea_documento(
      righe: [riga1, riga2],
      causale: causali(:scarico_saggi),
      clientable: @scuola,
      data: Date.current
    )

    documento.destroy

    [riga1, riga2].each do |riga|
      riga.reload
      assert_equal "rientrato", riga.esito,        "esito di #{riga.id} deve diventare rientrato"
      assert_not_nil riga.processato_at,           "processato_at di #{riga.id} deve restare valorizzato"
      assert_nil riga.documento_riga_id,           "documento_riga_id di #{riga.id} deve essere azzerato"
    end
  end

  test "destroy di una singola documento_riga marca solo la bv_riga collegata come rientrata" do
    riga1 = bolla_visione_righe(:aperta)
    riga2 = bolla_visione_righe(:aperta_due)

    documento = @ritiro.crea_documento(
      righe: [riga1, riga2],
      causale: causali(:scarico_saggi),
      clientable: @scuola,
      data: Date.current
    )

    dr1 = riga1.reload.documento_riga
    dr1.destroy

    riga1.reload
    assert_equal "rientrato", riga1.esito
    assert_not_nil riga1.processato_at
    assert_nil riga1.documento_riga_id

    riga2.reload
    assert_equal "in_saggio", riga2.esito
    assert_not_nil riga2.processato_at
    assert_not_nil riga2.documento_riga_id
  end

  test "crea_documento rollback se Riga.create! fallisce a metà; nessun Documento; riga non chiusa" do
    riga1 = bolla_visione_righe(:aperta)
    riga2 = bolla_visione_righe(:aperta_due)

    call_count = 0
    original_create = Riga.method(:create!)

    Riga.singleton_class.send(:alias_method, :__orig_create_bang!, :create!)
    Riga.define_singleton_method(:create!) do |*args, **kwargs|
      call_count += 1
      raise ActiveRecord::RecordInvalid.new(Riga.new) if call_count == 2
      original_create.call(*args, **kwargs)
    end

    begin
      assert_no_difference ["Documento.count", "DocumentoRiga.count", "Riga.count"] do
        assert_raises ActiveRecord::RecordInvalid do
          @ritiro.crea_documento(
            righe: [riga1, riga2],
            causale: causali(:scarico_saggi),
            clientable: @scuola,
            data: Date.current
          )
        end
      end
    ensure
      Riga.singleton_class.send(:alias_method, :create!, :__orig_create_bang!)
      Riga.singleton_class.send(:remove_method, :__orig_create_bang!)
    end

    riga1.reload
    assert_nil riga1.processato_at, "la prima BV riga non deve risultare processata dopo rollback"
  end
end
