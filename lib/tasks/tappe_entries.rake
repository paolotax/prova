namespace :tappe do
  desc "Backfill: create entries for tappe without entry (today/past get entry, past get closed)"
  task backfill_entries: :environment do
    tappa_ids_with_entry = Entry.where(entryable_type: "Tappa").pluck(:entryable_id)

    tappe = Tappa.where("data_tappa IS NOT NULL AND data_tappa <= ?", Date.today)
                 .where.not(id: tappa_ids_with_entry)

    puts "Tappe da processare: #{tappe.count}"

    tappe.find_each do |tappa|
      entry = tappa.ensure_entry!
      if tappa.data_tappa < Date.today && entry.present?
        entry.close(user: tappa.user) unless entry.closed?
        print "x"
      else
        print "."
      end
    end

    puts "\nDone!"
  end
end
