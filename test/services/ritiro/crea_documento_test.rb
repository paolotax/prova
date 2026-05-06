require "test_helper"

class Ritiro::CreaDocumentoTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :editori, :categorie, :libri, :scuole,
           :collane, :bolle_visione, :bolla_visione_righe, :causali

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @riga1 = bolla_visione_righe(:aperta)
    @riga2 = bolla_visione_righe(:aperta_due)
  end

  test "crea documento con causale, clientable e righe; chiude bolle_visione_righe" do
    documento = Ritiro::CreaDocumento.new(
      righe: [@riga1, @riga2],
      causale: causali(:scarico_saggi),
      clientable: @scuola,
      data: Date.current
    ).call

    assert_equal causali(:scarico_saggi), documento.causale
    assert_equal @scuola, documento.clientable
    assert_equal 2, documento.documento_righe.count

    @riga1.reload
    assert_equal "in_saggio", @riga1.esito
    assert_not_nil @riga1.processato_at
    assert_not_nil @riga1.documento_riga_id
    assert_equal @riga1.libro_id, @riga1.documento_riga.riga.libro_id
  end

  test "raises ArgumentError quando causale è nil; nessun documento creato; riga non chiusa" do
    assert_no_difference "Documento.count" do
      assert_raises ArgumentError do
        Ritiro::CreaDocumento.new(
          righe: [@riga1], causale: nil, clientable: @scuola, data: Date.current
        ).call
      end
    end
    @riga1.reload
    assert_nil @riga1.processato_at
  end

  test "rollback se Riga.create! fallisce a metà; nessun Documento creato; @riga1 non chiusa" do
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
          Ritiro::CreaDocumento.new(
            righe: [@riga1, @riga2],
            causale: causali(:scarico_saggi),
            clientable: @scuola,
            data: Date.current
          ).call
        end
      end
    ensure
      Riga.singleton_class.send(:alias_method, :create!, :__orig_create_bang!)
      Riga.singleton_class.send(:remove_method, :__orig_create_bang!)
    end

    @riga1.reload
    assert_nil @riga1.processato_at, "la prima BV riga non deve risultare processata dopo rollback"
    assert_nil @riga1.documento_riga_id
  end
end
