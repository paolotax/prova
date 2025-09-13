# == Schema Information
#
# Table name: stats
#
#  id              :integer          not null, primary key
#  descrizione     :string
#  seleziona_campi :string
#  raggruppa_per   :string
#  ordina_per      :string
#  condizioni      :string
#  testo           :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  titolo          :string
#  categoria       :string
#  anno            :string
#

class Stat < ApplicationRecord

    positioned on: [:categoria], column: :position

    def test_execution
        begin
            # Try to execute the SQL with a test user
            test_user = User.first
            execute(test_user)
            # If execution succeeds, ensure it's visible
            update_column(:visible, true)
            return true
        rescue => e
            # If execution fails, set visible to false
            update_column(:visible, false)
            return false
        end
    end

    def execute(user)
        sql = self.testo
        sql.gsub!("{{user.id}}", user.id.to_s)
        sql.gsub!(":user_id", user.id.to_s)
        ActiveRecord::Base.connection.execute(sql)
    end

    def raggruppa
        if self.raggruppa_per.blank?
            return []
        else
            self.raggruppa_per.split(",")
        end
    end

    def totali
        if self.seleziona_campi.blank?
            return []
        else
            self.seleziona_campi.split(",")
        end
    end

end
