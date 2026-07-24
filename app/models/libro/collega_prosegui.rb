# frozen_string_literal: true

# Collega prosegue_in per i libri dell'account dove il candidato e' univoco.
# Idempotente: salta i libri gia' collegati. Ritorna il numero di link creati.
class Libro::CollegaProsegui
  def initialize(account:)
    @account = account
  end

  def call
    creati = 0
    @account.libri.where(prosegue_in_id: nil).where.not(titolo: [nil, ""]).where.not(classe: nil)
            .find_each do |libro|
      candidati = libro.candidati_prosegui.to_a
      next unless candidati.size == 1

      libro.update!(prosegue_in: candidati.first)
      creati += 1
    end
    creati
  end
end
