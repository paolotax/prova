module Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, as: :closeable, dependent: :destroy

    # Cast id to text per compatibilità uuid/bigint con closeable_id string
    scope :closed, -> {
      where("#{table_name}.id::text IN (SELECT closeable_id FROM closures WHERE closeable_type = ?)", name)
    }
    scope :open, -> {
      where("#{table_name}.id::text NOT IN (SELECT closeable_id FROM closures WHERE closeable_type = ?)", name)
    }

    scope :recently_closed_first, -> {
      closed.joins("INNER JOIN closures ON closures.closeable_id = #{table_name}.id::text AND closures.closeable_type = '#{name}'")
            .order("closures.created_at DESC")
    }
    scope :closed_at_window, ->(window) {
      closed.joins("INNER JOIN closures ON closures.closeable_id = #{table_name}.id::text AND closures.closeable_type = '#{name}'")
            .where(closures: { created_at: window })
    }
    scope :closed_by, ->(users) {
      closed.joins("INNER JOIN closures ON closures.closeable_id = #{table_name}.id::text AND closures.closeable_type = '#{name}'")
            .where(closures: { user_id: Array(users) })
    }
  end

  def closed?
    closure.present?
  end

  def open?
    !closed?
  end

  def closed_by
    closure&.user
  end

  def closed_at
    closure&.created_at
  end

  def close(user: Current.user)
    unless closed?
      transaction do
        not_now&.destroy
        entry&.update!(column_id: nil) if respond_to?(:entry) && entry&.column_id.present?
        create_closure! user: user
        #track_event :closed, creator: user
      end
    end
  end

  def reopen(user: Current.user)
    if closed?
      transaction do
        closure&.destroy
        track_event :reopened, creator: user
      end
    end
  end
end
