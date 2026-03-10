class FixTappeTappableIdAcrossAccounts < ActiveRecord::Migration[8.1]
  def up
    fixed = 0
    skipped = 0
    orphaned = 0

    Tappa.where(tappable_type: "Scuola").find_each do |tappa|
      scuola = Scuola.find_by(id: tappa.tappable_id)

      unless scuola
        orphaned += 1
        next
      end

      # Already correct
      next if scuola.account_id == tappa.account_id

      # Find matching scuola in tappa's account by codice_ministeriale
      correct_scuola = Scuola.find_by(
        account_id: tappa.account_id,
        codice_ministeriale: scuola.codice_ministeriale
      )

      if correct_scuola
        tappa.update_columns(tappable_id: correct_scuola.id)
        fixed += 1
      else
        skipped += 1
        say "SKIP: tappa #{tappa.id} (#{tappa.data_tappa}) -> #{scuola.denominazione} (#{scuola.codice_ministeriale}) no match in account #{tappa.account_id}"
      end
    end

    say "Fixed: #{fixed}, Skipped: #{skipped}, Orphaned: #{orphaned}"
  end

  def down
    # Non reversibile — i vecchi tappable_id erano sbagliati
  end
end
