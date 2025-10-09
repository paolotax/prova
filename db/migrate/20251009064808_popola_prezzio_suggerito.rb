class PopolaPrezzioSuggerito < ActiveRecord::Migration[8.0]
  def up
    # Calcola il prezzo suggerito: prezzo con sconto 10%, arrotondato al decimo superiore (0.10€ = 10 cents)
    # Esempio: 15.41€ (1541 cents) * 0.9 = 1386.9 cents -> arrotonda a 1390 cents (13.90€)
    # Esempio: 15.50€ (1550 cents) * 0.9 = 1395 cents -> arrotonda a 1400 cents (14.00€)
    # Formula: CEIL((prezzo_in_cents * 0.9) / 10.0) * 10
    execute <<-SQL
      UPDATE libri
      SET prezzo_suggerito_cents = CEIL((prezzo_in_cents * 0.9) / 10.0) * 10
      WHERE prezzo_in_cents > 0
    SQL
  end

  def down
    # Resetta il prezzo_suggerito_cents a 0
    execute <<-SQL
      UPDATE libri
      SET prezzo_suggerito_cents = 0
    SQL
  end
end
