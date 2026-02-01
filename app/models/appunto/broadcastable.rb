module Appunto::Broadcastable
  extend ActiveSupport::Concern

  included do
    # Broadcast refresh to the appunto's own channel (for show page)
    broadcasts_refreshes

    # Broadcast refresh to user's appunti list channel
    broadcasts_refreshes_to ->(appunto) { [appunto.user, "appunti"] }
  end
end
