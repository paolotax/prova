module Accounts
  class Mandato < ApplicationRecord
    self.table_name = "mandati"

    include AccountScoped

    belongs_to :editore

    validates :editore_id, uniqueness: { scope: [:account_id, :provincia, :grado, :anno_scolastico] }

    scope :attivi, -> { where(disdetta: false) }
    scope :disdetti, -> { where(disdetta: true) }

    after_commit :update_mie_adozioni_async, on: [:create, :destroy]
    after_update_commit :update_mie_adozioni_async, if: :saved_change_to_disdetta?

    def copre_scuola?(scuola)
      (provincia.nil? || provincia == scuola.provincia) &&
        (grado.nil? || grado == scuola.grado)
    end

    private

    def update_mie_adozioni_async
      UpdateMieAdozioniJob.perform_later(account)
    end
  end
end
