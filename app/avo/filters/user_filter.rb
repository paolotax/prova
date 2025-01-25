module Avo
  module Filters
    class UserFilter < Avo::Filters::SelectFilter
      self.name = "Utente"

      def apply(request, query, value)
        query.where(user_id: value)
      end

      def options
        User.all.map { |user| [user.name, user.id] }.to_h
      end
    end
  end
end 