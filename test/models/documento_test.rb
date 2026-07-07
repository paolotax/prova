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
  fixtures :accounts, :users, :memberships, :documenti, :clienti, :causali

  setup do
    @fizzy = accounts(:fizzy)
    @user = users(:one)
    Current.account = @fizzy
    Current.user = @user
  end

  teardown do
    Current.reset
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
end
