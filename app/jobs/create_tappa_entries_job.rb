class CreateTappaEntriesJob < ApplicationJob
  queue_as :default

  def perform
    tappa_ids_with_entry = Entry.where(entryable_type: "Tappa").pluck(:entryable_id)

    Tappa.where(data_tappa: Date.today)
         .where.not(id: tappa_ids_with_entry)
         .find_each do |tappa|
      tappa.ensure_entry!
    end
  end
end
