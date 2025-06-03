class UpdateStatsRecords < ActiveRecord::Migration[7.0]
  def up
    Stat.find_each do |stat|
      descrizione = stat.descrizione.to_s.downcase

      # Extract year if present (including 025 as 2025)
      if descrizione.match?(/2025|025/)
        stat.anno = "2025"
      end

      # Extract category
      if descrizione.include?("user") || descrizione.include?("utente")
        stat.categoria = "utenti"
      elsif descrizione.include?("titoli")
        stat.categoria = "titoli"
      elsif descrizione.include?("editori")
        stat.categoria = "editori"
      elsif descrizione.include?("province")
        stat.categoria = "province"
      else
        stat.categoria = "altre"
      end

      # Clean up description for title
      new_descrizione = descrizione
        .gsub(/2025|025/, '')
        .gsub(/user|utente/, '')
        .gsub(/titoli/, '')
        .gsub(/editori/, '')
        .gsub(/province/, '')
        .gsub(/-/, '')  # Remove hyphens
        .strip

      # Set the cleaned description as title
      stat.titolo = new_descrizione

      # Keep original description unchanged
      stat.save!
    end
  end

  def down
    # No need for down migration as we're just updating data
  end
end