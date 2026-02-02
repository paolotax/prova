module Pagabile
  extend ActiveSupport::Concern

  included do
    has_one :pagamento, as: :pagabile, dependent: :destroy
  end

  def mark_pagato(user: Current.user, pagato_il: nil, tipo_pagamento: nil)
    pagato_il ||= Time.current
    create_pagamento!(user: user, pagato_il: pagato_il, tipo_pagamento: tipo_pagamento, account: Current.account) unless pagato?
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

  def tipo_pagamento
    pagamento&.tipo_pagamento
  end
end
