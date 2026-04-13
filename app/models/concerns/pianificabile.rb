module Pianificabile
  extend ActiveSupport::Concern

  def tappa_target
    self
  end

  def default_titolo_tappa
    nil
  end
end
