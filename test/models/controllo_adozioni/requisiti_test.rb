require "test_helper"

class ControlloAdozioni::RequisitiTest < ActiveSupport::TestCase
  R = ControlloAdozioni::Requisiti

  test "la 2a non richiede religione" do
    chiavi = R.per_classe("2").map(&:chiave)
    assert_includes chiavi, :sussidiario_1biennio
    assert_includes chiavi, :inglese
    assert_not_includes chiavi, :religione_alt
  end

  test "la 4a richiede religione e il sussidiario discipline" do
    chiavi = R.per_classe("4").map(&:chiave)
    assert_includes chiavi, :religione_alt
    assert_includes chiavi, :sussidiario_discipline
  end

  test "religione_alt e' soddisfatto da RELIGIONE o ADOZIONE ALTERNATIVA" do
    req = R.per_classe("1").find { |r| r.chiave == :religione_alt }
    assert req.soddisfatto?(["RELIGIONE CATTOLICA"])
    assert req.soddisfatto?(["ADOZIONE ALTERNATIVA ART. 156 D.L. 297/94"])
    assert_not req.soddisfatto?(["LINGUA INGLESE"])
  end

  test "sussidiario_discipline soddisfatto da unico OPPURE coppia ambiti" do
    req = R.per_classe("4").find { |r| r.chiave == :sussidiario_discipline }
    assert req.soddisfatto?(["SUSSIDIARIO DELLE DISCIPLINE"]), "unico"
    assert req.soddisfatto?([
      "SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)",
      "SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)"
    ]), "coppia"
    assert_not req.soddisfatto?(["SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)"]), "solo antropologico = NON soddisfatto"
  end
end
