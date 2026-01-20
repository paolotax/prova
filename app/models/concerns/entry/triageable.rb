# frozen_string_literal: true

module Entry::Triageable
  extend ActiveSupport::Concern

  def triage_into(column)
    transaction do
      resume if postponed?
      update!(column: column)
      track_event :triaged, particulars: { column: column.name }
    end
  end

  def send_back_to_triage
    transaction do
      resume if postponed?
      update!(column: nil)
      track_event :sent_back_to_triage
    end
  end

  def move_to_column(column)
    return if self.column == column

    transaction do
      old_column_name = self.column&.name
      update!(column: column)
      track_event :triaged, particulars: {
        from_column: old_column_name,
        to_column: column&.name
      }
    end
  end
end
