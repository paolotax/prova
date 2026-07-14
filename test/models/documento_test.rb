# == Schema Information
#
# Table name: documenti
#
#  id                      :uuid             not null, primary key
#  clientable_type         :string
#  data_documento          :date
#  iva_cents               :bigint
#  note                    :text
#  numero_documento        :integer
#  referente               :text
#  spese_cents             :bigint
#  tipo_documento          :integer
#  tipo_pagamento_previsto :string
#  totale_cents            :bigint
#  totale_copie            :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :uuid             not null
#  causale_id              :bigint
#  clientable_id           :uuid
#  derivato_da_causale_id  :integer
#  documento_padre_id      :uuid
#  user_id                 :bigint           not null
#
# Indexes
#
#  index_documenti_on_account_id                 (account_id)
#  index_documenti_on_account_id_and_created_at  (account_id,created_at)
#  index_documenti_on_causale_id                 (causale_id)
#  index_documenti_on_clientable                 (clientable_type,clientable_id)
#  index_documenti_on_derivato_da_causale_id     (derivato_da_causale_id)
#  index_documenti_on_documento_padre_id         (documento_padre_id)
#  index_documenti_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (causale_id => causali.id)
#  fk_rails_...  (derivato_da_causale_id => causali.id)
#  fk_rails_...  (documento_padre_id => documenti.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class DocumentoTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :documenti, :clienti, :causali,
           :libri, :categorie, :editori, :righe, :documento_righe

  setup do
    @fizzy = accounts(:fizzy)
    @user = users(:one)
    Current.account = @fizzy
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  test "scope da_pagare include i parzialmente pagati ed esclude i saldati" do
    documento = documenti(:fattura_uno)
    assert_includes Documento.da_pagare, documento

    documento.registra_acconto!(importo_cents: 1000)
    assert_includes Documento.da_pagare, documento

    documento.mark_pagato
    assert_not_includes Documento.da_pagare, documento
  end

  test "scope da_consegnare include i parzialmente consegnati ed esclude i saturati" do
    documento = documenti(:fattura_uno)
    documento_riga = documento_righe(:dr_fattura_uno)
    assert_includes Documento.da_consegnare, documento

    documento.consegna_parziale!({ documento_riga.id => 12 })
    assert_includes Documento.da_consegnare, documento

    documento.consegna_parziale!({ documento_riga.id => 8 })
    assert_not_includes Documento.da_consegnare, documento
  end

  test "tappa_target is clientable when real" do
    documento = documenti(:documento_fizzy)
    assert_equal documento.clientable, documento.tappa_target
  end

  test "tappa_target is nil for NessunCliente" do
    documento = documenti(:documento_fizzy)
    documento.clientable = nil
    assert_instance_of Domain::NessunCliente, documento.clientable
    assert_nil documento.tappa_target
  end

  test "pagamento_applicabile? is true for a causale with gestione_pagamento" do
    documento = documenti(:documento_fizzy) # causale: vendita
    assert documento.causale.gestione_pagamento?
    assert documento.pagamento_applicabile?
  end

  test "pagamento_applicabile? is false for a causale without gestione_pagamento" do
    documento = documenti(:ddt_fornitore_fizzy) # causale: carico_fornitore
    assert_not documento.causale.gestione_pagamento?
    assert_not documento.pagamento_applicabile?
  end

  test "pagamento_applicabile? is true for a documento without causale (bozza)" do
    documento = documenti(:documento_fizzy)
    documento.causale = nil
    assert documento.pagamento_applicabile?
  end

  test "consegna_applicabile? is true for a causale with gestione_consegna" do
    documento = documenti(:documento_fizzy) # causale: vendita
    assert documento.causale.gestione_consegna?
    assert documento.consegna_applicabile?
  end

  test "consegna_applicabile? is false for a causale without gestione_consegna" do
    documento = documenti(:ddt_fornitore_fizzy) # causale: carico_fornitore
    assert_not documento.causale.gestione_consegna?
    assert_not documento.consegna_applicabile?
  end

  test "consegna_applicabile? is true for a documento without causale (bozza)" do
    documento = documenti(:documento_fizzy)
    documento.causale = nil
    assert documento.consegna_applicabile?
  end

  test "mostra_importo? is true for a causale with mostra_importo" do
    documento = documenti(:documento_fizzy) # causale: vendita
    assert documento.causale.mostra_importo?
    assert documento.mostra_importo?
  end

  test "mostra_importo? is false for a causale without mostra_importo" do
    documento = documenti(:scarico_saggi_fizzy) # causale: scarico_saggi
    assert_not documento.causale.mostra_importo?
    assert_not documento.mostra_importo?
  end

  test "mostra_importo? is true for a documento without causale (bozza)" do
    documento = documenti(:documento_fizzy)
    documento.causale = nil
    assert documento.mostra_importo?
  end
end
