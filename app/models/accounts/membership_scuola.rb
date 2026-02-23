# == Schema Information
#
# Table name: membership_scuole
#
#  id            :uuid             not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  membership_id :uuid             not null
#  scuola_id     :uuid             not null
#
# Indexes
#
#  index_membership_scuole_on_membership_id                (membership_id)
#  index_membership_scuole_on_membership_id_and_scuola_id  (membership_id,scuola_id) UNIQUE
#  index_membership_scuole_on_scuola_id                    (scuola_id)
#
module Accounts
  class MembershipScuola < ApplicationRecord
    self.table_name = "membership_scuole"

    belongs_to :membership, class_name: "Accounts::Membership"
    belongs_to :scuola

    validates :scuola_id, uniqueness: { scope: :membership_id }
  end
end
