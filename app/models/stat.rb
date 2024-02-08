class Stat < ApplicationRecord


    def execute(user)
        sql = self.testo
        ActiveRecord::Base.connection.execute(sql)
    end

end
