# == Schema Information
#
# Table name: stats
#
#  id              :bigint           not null, primary key
#  descrizione     :string
#  seleziona_campi :string
#  raggruppa_per   :string
#  ordina_per      :string
#  condizioni      :string
#  testo           :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Stat < ApplicationRecord


    def execute(user)
        sql = self.testo
        sql.gsub!("{{user.id}}", user.id.to_s)
        ActiveRecord::Base.connection.execute(sql)
    end

    def raggruppa
        if self.raggruppa_per.blank?
            return []
        else
            self.raggruppa_per.split(",")
        end
    end

end
