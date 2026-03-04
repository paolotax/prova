module Navigable
  extend ActiveSupport::Concern

  def navigable?
    geocoded? || indirizzo_navigator.present?
  end
end
