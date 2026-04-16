module Filters
  class TappaFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      def count_oggi
        user_tappe_scope.di_oggi.count
      end

      def count_domani
        user_tappe_scope.di_domani.count
      end

      def count_programmate
        user_tappe_scope.programmate.count
      end

      def count_da_programmare
        user_tappe_scope.da_programmare.count
      end

      private

      def user_tappe_scope
        ::Tappa.where(account: account || Current.account, user: creator)
      end
    end
  end
end
