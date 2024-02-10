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
