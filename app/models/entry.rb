# frozen_string_literal: true

# == Schema Information
#
# Table name: entries
#
#  id             :uuid             not null, primary key
#  entryable_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :uuid             not null
#  column_id      :uuid
#  entryable_id   :string           not null
#  giro_id        :bigint
#  user_id        :bigint           not null
#
# Indexes
#
#  index_entries_on_account_id                       (account_id)
#  index_entries_on_account_id_and_entryable_type    (account_id,entryable_type)
#  index_entries_on_column_id                        (column_id)
#  index_entries_on_entryable_type_and_entryable_id  (entryable_type,entryable_id) UNIQUE
#  index_entries_on_giro_id                          (giro_id)
#  index_entries_on_user_id                          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (column_id => columns.id)
#  fk_rails_...  (giro_id => giri.id)
#  fk_rails_...  (user_id => users.id)
#

class Entry < ApplicationRecord
  include AccountScoped

  # Entry concerns for state management
  include Entry::Triageable
  include Entry::Eventable
  include Entry::Golden
  include Entry::Closeable
  include Entry::Postponable

  # Turbo broadcasts for real-time updates (kanban, show pages)
  include Entry::Broadcastable

  # Delegated Type
  delegated_type :entryable, types: %w[Appunto Documento Tappa], dependent: :destroy

  # Associations
  belongs_to :column, optional: true
  belongs_to :giro, optional: true
  belongs_to :user

  has_many :events, dependent: :destroy

  # State records (pointing to Entry now)
  has_one :goldness, dependent: :destroy
  has_one :closure, dependent: :destroy
  has_one :not_now, dependent: :destroy

  # Scopes for triage states
  scope :awaiting_triage, -> { active.where(column_id: nil) }
  scope :triaged, -> { active.where.not(column_id: nil) }
  scope :active, -> { aperti.where.missing(:not_now) }
  scope :aperti, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }
  scope :postponed, -> { joins(:not_now) }
  scope :golden, -> { joins(:goldness) }

  # Convenience scopes per tipo
  scope :appunti, -> { where(entryable_type: "Appunto") }
  scope :documenti, -> { where(entryable_type: "Documento") }
  scope :tappe, -> { where(entryable_type: "Tappa") }

  # Exclude ssk appunti (saggio, seguito, kit) - these will be moved to a separate model later
  # Keep: documenti, tappe, and appunti that are NOT ssk
  scope :non_ssk, -> {
    ssk_appunto_ids = Appunto.ssk.pluck(:id).map(&:to_s)
    if ssk_appunto_ids.any?
      where.not(entryable_type: "Appunto")
        .or(where(entryable_type: "Appunto").where.not(entryable_id: ssk_appunto_ids))
    else
      all
    end
  }

  # Per giro
  scope :for_giro, ->(giro) { where(giro: giro) }
  scope :without_giro, -> { where(giro_id: nil) }

  # Order scopes
  scope :recent, -> { order(updated_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }

  # Goldness-first ordering: golden items appear first
  scope :with_golden_first, -> {
    left_outer_joins(:goldness).order(Arel.sql("goldnesses.id IS NULL"))
  }

  # For column counts
  scope :in_column, ->(column) { where(column: column) }

  def awaiting_triage?
    active? && column_id.nil?
  end

  def triaged?
    active? && column_id.present?
  end

  # Override entryable_id getter/setter for polymorphic support
  # All entryables now use UUID (Appunto, Documento, Tappa)
  def entryable
    return @entryable if defined?(@entryable)

    @entryable = case entryable_type
                 when "Appunto"
                   Appunto.find_by(id: entryable_id)
                 when "Documento"
                   Documento.find_by(id: entryable_id)
                 when "Tappa"
                   Tappa.find_by(id: entryable_id)
                 end
  end

  # Batch-load entryables to avoid N+1 (entryable_id is string)
  def self.load_entryables(entries)
    entries = entries.to_a
    by_type = entries.group_by(&:entryable_type)

    loaded = {}
    {
      "Appunto"   => ->(ids) { Appunto.where(id: ids).includes(:appuntabile, :consegna, righe: :libro) },
      "Documento" => ->(ids) { Documento.where(id: ids).includes(:clientable, :consegna, righe: :libro) }
    }.each do |type, loader|
      next unless by_type[type]
      loader.call(by_type[type].map(&:entryable_id)).each { |r| loaded[r.id.to_s] = r }
    end

    entries.each { |e| e.instance_variable_set(:@entryable, loaded[e.entryable_id]) }
    entries
  end

  def destinatario
    case entryable
    when Appunto then entryable.appuntabile
    when Documento then entryable.clientable
    end
  end

  def entryable=(record)
    @entryable = record
    self.entryable_type = record.class.name
    self.entryable_id = record.id.to_s
  end

end
