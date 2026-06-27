# == Schema Information
#
# Table name: propagande
#
#  id         :uuid             not null, primary key
#  nome       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :uuid             not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_propagande_on_account_id  (account_id)
#  index_propagande_on_user_id     (user_id)
#
require "test_helper"

class PropagandaTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :scuole, :collane,
           :categorie, :editori, :libri, :bolle_visione, :bolla_visione_righe

  setup do
    @fizzy  = accounts(:fizzy)
    @user   = users(:one)
    @scuola = scuole(:scuola_fizzy)
    Current.account = @fizzy
    Current.user = @user
    Current.membership = @user.memberships.find_by(account: @fizzy)

    @propaganda = @user.propagande.create!(account: @fizzy, nome: "Propaganda Test")
    @giro = @user.giri.create!(titolo: "Collane test", propaganda: @propaganda)
    # lega la bolla esistente (bv_fizzy_uno → scuola_fizzy) a una tappa del giro
    @tappa = @user.tappe.create!(tappable: @scuola, data_tappa: Date.current)
    @tappa.tappa_giri.create!(giro: @giro)
    bolle_visione(:bv_fizzy_uno).update!(tappa: @tappa)
  end

  teardown { Current.reset }

  test ".corrente prende la propaganda più recente dell'utente" do
    @user.propagande.create!(account: @fizzy, nome: "Più recente")
    assert_equal "Più recente", Propaganda.corrente(user: @user).nome
  end

  test "#scuole sono quelle con bolle nei giri della propaganda" do
    assert_includes @propaganda.scuole, @scuola
  end

  test "#andamento raggruppa per scuola × collana × gruppo" do
    cs = @propaganda.andamento([@scuola]).first
    assert_equal @scuola, cs.scuola

    collana = cs.collane.find { |c| c.collana == collane(:collana_fizzy) }
    assert collana, "deve esserci la collana_fizzy"

    # bv_fizzy_uno: aperta(1)+aperta_due(2)+aperta_confezione(1)=4 aperte; chiusa_in_saggio(1) chiusa
    assert_equal 4, collana.da_ritirare
    assert_equal 5, collana.totale
    refute collana.completata?
  end

  test "#andamento espone mancanti e completata per scuola" do
    riga = bolla_visione_righe(:aperta)
    riga.update!(esito: :mancante)

    cs = @propaganda.andamento([@scuola]).first
    assert_equal 1, cs.mancanti
    refute cs.completata?
  end

  test "scuola completata quando nessuna riga è aperta" do
    @scuola.bolle_visione.each do |b|
      b.bolla_visione_righe.update_all(esito: BollaVisioneRiga.esiti[:rientrato])
    end
    cs = @propaganda.andamento([@scuola]).first
    assert cs.completata?
    assert_equal 0, cs.da_ritirare
  end

  test "#riepilogo conta codici scuola distinct: consegne vs ritiri" do
    # @giro "Collane test" (consegna) ha la tappa di oggi su @scuola -> non completata
    r = @propaganda.riepilogo
    assert_equal 1, r[:consegne][:totale]
    assert_equal 0, r[:consegne][:completate], "tappa di oggi non è ancora completata"
    assert_equal({ totale: 0, completate: 0, senza_bolla: 0 }, r[:ritiri], "nessun giro di ritiro")

    # aggiungo un giro di ritiro con tappa passata sulla stessa scuola
    ritiro = @user.giri.create!(titolo: "Ritiri '26", propaganda: @propaganda)
    tappa_ieri = @user.tappe.create!(tappable: @scuola, data_tappa: Date.yesterday)
    tappa_ieri.tappa_giri.create!(giro: ritiro)
    @propaganda.giri.reload

    r = @propaganda.riepilogo
    assert_equal 1, r[:ritiri][:totale]
    assert_equal 1, r[:ritiri][:completate], "tappa di ieri è completata"
  end

  test "#riepilogo segnala le scuole con tappa ma senza bolla" do
    # @scuola ha bolle (fixture); aggiungo una seconda scuola con tappa ma niente bolla.
    altra = scuole(:scuola_fizzy_nord)
    tappa = @user.tappe.create!(tappable: altra, data_tappa: Date.current)
    tappa.tappa_giri.create!(giro: @giro)
    @propaganda.giri.reload

    r = @propaganda.riepilogo
    assert_equal 1, r[:consegne][:senza_bolla],
      "la scuola con tappa ma senza bolla va segnalata, non sparisce silenziosamente"
  end

  test "#tappe_senza_bolla elenca le tappe la cui scuola non ha bolle" do
    altra = scuole(:scuola_fizzy_nord)
    tappa = @user.tappe.create!(tappable: altra, data_tappa: Date.current)
    tappa.tappa_giri.create!(giro: @giro)
    @propaganda.giri.reload

    tappe = @propaganda.tappe_senza_bolla
    assert_includes tappe, tappa, "la tappa senza bolla deve comparire"
    refute_includes tappe, @tappa, "@scuola ha una bolla: la sua tappa non va elencata"
  end

  test "i titoli di una collana sono ordinati per position del CollanaLibro" do
    cl = collane(:collana_fizzy)
    CollanaLibro.create!(account: @fizzy, collana: cl, libro: libri(:libro_fizzy), gruppo: "G1", position: 2)
    CollanaLibro.create!(account: @fizzy, collana: cl, libro: libri(:confezione_fizzy), gruppo: "G1", position: 1)

    collana = @propaganda.andamento([@scuola]).first.collane.find { |c| c.collana == cl }
    gruppo, righe = collana.gruppi.first
    assert_equal "G1", gruppo
    assert_equal libri(:confezione_fizzy).titolo, righe.first.titolo
  end
end
