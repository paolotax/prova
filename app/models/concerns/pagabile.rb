module Pagabile
  extend ActiveSupport::Concern

  included do
    has_one :pagamento, as: :pagabile, dependent: :destroy
  end

  def mark_pagato(user: Current.user)
    create_pagamento!(user: user, pagato_il: Time.current) unless pagato?
  end

  def unmark_pagato
    pagamento&.destroy
  end

  def pagato?
    pagamento.present?
  end

  def pagato_il
    pagamento&.pagato_il
  end
end
