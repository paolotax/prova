require "test_helper"

class GiacenzeControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :clienti, :causali, :categorie, :editori, :libri

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @cliente = clienti(:cliente_fizzy)
    sign_in_as(@user, @account)
  end

  test "la testata mostra sei card, i conteggi dell'anno e il venduto in euro" do
    libro = crea_libro("Zibaldone Conteggi")
    libro.update_column(:adozioni_count, 12)
    crea_documento(causali(:campionario), libro: libro, quantita: 10)
    vendita = crea_documento(causali(:fattura), libro: libro, quantita: 6)
    vendita.consegna_parziale!({ vendita.documento_righe.first.id => 4 })

    # terms isola il libro: i totali della testata diventano deterministici,
    # non inquinati dai documenti fixture su libro_fizzy.
    get giacenze_path(account_id: @account.id, terms: [ "Zibaldone" ])

    assert_response :success
    assert_select "h1", /Giacenze di magazzino/
    assert_select ".analytics-summary .analytics-summary__card", count: 6
    assert_no_match(/Fabbisogno/, response.body)
    assert_match "Zibaldone Conteggi", response.body

    # Ordine card: adottati, campionario, scarico saggi, vendute, da consegnare, venduto.
    valori = css_select(".analytics-summary__card .analytics-summary__value").map { |n| n.text.strip }
    assert_equal 6, valori.size
    assert_equal "12", valori[0]           # adottati (counter)
    assert_equal "10", valori[1]           # campionario
    assert_equal "0",  valori[2]           # scarico saggi
    assert_equal "4",  valori[3]           # vendute (copie consegnate)
    assert_equal "2",  valori[4]           # da consegnare (residuo)
    assert_match(/400,00/, valori[5])      # venduto in euro, formato italiano

    labels = css_select(".analytics-summary__card .analytics-summary__label").map { |n| n.text.strip }
    assert_equal %w[adottati campionario], labels.first(2)
    assert_includes labels, "vendute"
    assert_includes labels, "da consegnare"
    assert_includes labels, "venduto"
  end

  test "il filtro anno cambia i conteggi mostrati" do
    libro = crea_libro("Almanacco Annuale")
    crea_documento(causali(:campionario), libro: libro, quantita: 10)
    crea_documento(causali(:campionario), libro: libro, quantita: 4, data: 1.year.ago.to_date)

    # Default: anno corrente -> 10 copie campionario.
    get giacenze_path(account_id: @account.id, terms: [ "Almanacco" ])
    assert_response :success
    assert_equal "10", campionario_card_value

    # Anno scorso -> 4 copie campionario.
    get giacenze_path(account_id: @account.id, terms: [ "Almanacco" ], anno: 1.year.ago.year)
    assert_response :success
    assert_equal "4", campionario_card_value
  end

  test "il filtro stato campionario include solo i libri con campionario nell'anno" do
    con_campionario = crea_libro("Codice Campionario")
    crea_documento(causali(:campionario), libro: con_campionario, quantita: 5)
    senza_campionario = crea_libro("Diario Vuoto")

    get giacenze_path(account_id: @account.id, stati: [ "campionario" ])

    assert_response :success
    assert_match "Codice Campionario", response.body
    assert_no_match "Diario Vuoto", response.body
  end

  test "il filtro stato venduti include solo i libri con copie consegnate" do
    venduto = crea_libro("Epistola Venduta")
    vendita = crea_documento(causali(:fattura), libro: venduto, quantita: 6)
    vendita.consegna_parziale!({ vendita.documento_righe.first.id => 4 })
    non_venduto = crea_libro("Favola Ferma")

    get giacenze_path(account_id: @account.id, stati: [ "venduti" ])

    assert_response :success
    assert_match "Epistola Venduta", response.body
    assert_no_match "Favola Ferma", response.body
  end

  test "lo stato fabbisogno (rimosso) viene ignorato e mostra tutti i libri" do
    libro = crea_libro("Grammatica Neutra")

    get giacenze_path(account_id: @account.id, stati: [ "fabbisogno" ])

    assert_response :success
    assert_match "Grammatica Neutra", response.body
    assert_match "Libro Test Fizzy", response.body
  end

  test "il filtro stato adottati usa il counter delle adozioni" do
    adottato = crea_libro("Poema Adottato")
    adottato.update_column(:adozioni_count, 5)
    neutro = crea_libro("Quaderno Zero")

    get giacenze_path(account_id: @account.id, stati: [ "adottati" ])

    assert_response :success
    assert_match "Poema Adottato", response.body
    assert_no_match "Quaderno Zero", response.body
  end

  test "il filtro stato impegnati include i libri con residuo da consegnare" do
    impegnato = crea_libro("Racconto Impegnato")
    crea_documento(causali(:fattura), libro: impegnato, quantita: 6) # nessuna consegna -> tutto da consegnare
    neutro = crea_libro("Saggio Sereno")

    get giacenze_path(account_id: @account.id, stati: [ "impegnati" ])

    assert_response :success
    assert_match "Racconto Impegnato", response.body
    assert_no_match "Saggio Sereno", response.body
  end

  test "ordina per la colonna campionario decrescente" do
    alto = crea_libro("Manuale Alto")
    crea_documento(causali(:campionario), libro: alto, quantita: 20)
    basso = crea_libro("Novella Bassa")
    crea_documento(causali(:campionario), libro: basso, quantita: 3)

    get giacenze_path(account_id: @account.id, stati: [ "campionario" ], sort: "campionario.desc")

    assert_response :success
    assert_operator response.body.index("Manuale Alto"), :<, response.body.index("Novella Bassa")
  end

  test "filtra per terms" do
    get giacenze_path(account_id: @account.id, terms: [ "confezione atlante" ])

    assert_response :success
    assert_match "Confezione Atlante", response.body
    assert_no_match "Libro Test Fizzy", response.body
  end

  test "filtra per categoria" do
    crea_libro("Enciclopedia Parascolastica", categoria: categorie(:parascolastico))
    crea_libro("Manuale Ministeriale", categoria: categorie(:ministeriali))

    get giacenze_path(account_id: @account.id, categorie: [ "parascolastico" ])

    assert_response :success
    assert_match "Enciclopedia Parascolastica", response.body
    assert_no_match "Manuale Ministeriale", response.body
  end

  test "ordina per titolo di default" do
    get giacenze_path(account_id: @account.id)

    assert_response :success
    assert_operator response.body.index("Atlante Fascicolo 1"), :<, response.body.index("Libro Test Fizzy")
  end

  test "applica il sort di colonna anche con un filtro attivo" do
    ultimo = crea_libro("Zzz Ultimo")
    ultimo.update_column(:adozioni_count, 3)
    primo = crea_libro("Aaa Primo")
    primo.update_column(:adozioni_count, 3)

    get giacenze_path(account_id: @account.id, stati: [ "adottati" ], sort: "titolo.asc")

    assert_response :success
    assert_operator response.body.index("Aaa Primo"), :<, response.body.index("Zzz Ultimo")
  end

  test "i totali della testata ignorano lo stato attivo" do
    libro = crea_libro("Bilancio Invariante")
    crea_documento(causali(:campionario), libro: libro, quantita: 10)
    vendita = crea_documento(causali(:fattura), libro: libro, quantita: 6)
    vendita.consegna_parziale!({ vendita.documento_righe.first.id => 4 })

    get giacenze_path(account_id: @account.id, terms: [ "Bilancio" ])
    assert_response :success
    senza_stato = campionario_card_value

    get giacenze_path(account_id: @account.id, terms: [ "Bilancio" ], stati: [ "venduti" ])
    assert_response :success
    assert_equal senza_stato, campionario_card_value
    assert_equal "10", campionario_card_value
  end

  test "la card attiva ha --active e il suo link fa da toggle (rimuove la chiave)" do
    get giacenze_path(account_id: @account.id, stati: [ "campionario" ])
    assert_response :success

    attiva = css_select("a.analytics-summary__card--active")
    assert_equal 1, attiva.size
    # Toggle off: la card attiva linka senza la propria chiave (niente stati).
    assert_no_match(/stati/, attiva.first["href"])
    assert_equal "campionario", attiva.first.css(".analytics-summary__label").text.strip

    # Una card non attiva è additiva: il suo link contiene sia la chiave già
    # attiva sia la propria (OR multi-select).
    venduti = css_select("a.analytics-summary__card--link").find do |a|
      a.css(".analytics-summary__label").text.strip == "vendute"
    end
    assert_not_nil venduti
    assert_includes venduti["href"], "campionario"
    assert_includes venduti["href"], "venduti"
  end

  test "la card del venduto in euro non e' un link" do
    get giacenze_path(account_id: @account.id)
    assert_response :success

    # 5 card cliccabili + la card venduto (div, non link).
    assert_select "a.analytics-summary__card--link", count: 5
    venduto = css_select(".analytics-summary__card").last
    assert_equal "venduto", venduto.css(".analytics-summary__label").text.strip
    assert_nil venduto["href"]
  end

  test "il filtro stato saggi_100 include solo i libri con saggi 100" do
    con_saggi = crea_libro("Trattato Saggiato")
    crea_documento(causali(:saggi_100), libro: con_saggi, quantita: 3)
    senza_saggi = crea_libro("Umorismo Vuoto")

    get giacenze_path(account_id: @account.id, stati: [ "saggi_100" ])

    assert_response :success
    assert_match "Trattato Saggiato", response.body
    assert_no_match "Umorismo Vuoto", response.body
  end

  private

    def campionario_card_value
      css_select(".analytics-summary__card .analytics-summary__value")[1].text.strip
    end

    def crea_libro(titolo, editore: editori(:mondadori), categoria: categorie(:ministeriali))
      Libro.create!(account: @account, user: @user, titolo: titolo,
                    codice_isbn: "TEST-#{SecureRandom.hex(4)}",
                    prezzo_in_cents: 10000, editore: editore,
                    categoria: categoria)
    end

    def crea_documento(causale, libro:, quantita:, data: Date.today, sconto: 0.0)
      documento = Documento.create!(account: @account, user: @user, causale: causale,
                                    clientable: @cliente, numero_documento: prossimo_numero,
                                    data_documento: data)
      riga = Riga.create!(libro: libro, quantita: quantita, prezzo_cents: 10000, sconto: sconto)
      documento.documento_righe.create!(riga: riga)
      documento
    end

    def prossimo_numero
      @numero = (@numero || 7000) + 1
    end

    def sign_in_as(user, account)
      session = user.sessions.create!(account: account)
      cookies[:session_token] = sign_cookie(session.token)
      Current.user = user
      Current.account = account
      Current.membership = user.memberships.find_by(account: account)
    end

    def sign_cookie(value)
      secret = Rails.application.key_generator.generate_key("signed cookie")
      ActiveSupport::MessageVerifier.new(secret, serializer: JSON).generate(value)
    end
end
