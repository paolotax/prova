# frozen_string_literal: true

module Entry::Broadcastable
  extend ActiveSupport::Concern

  included do
    # Broadcast refresh to the entry's own channel (for show pages)
    broadcasts_refreshes

    # Broadcast refresh to user's entries channel (for kanban/dashboard)
    broadcasts_refreshes_to ->(entry) { [entry.user, "entries"] }
  end
end
