module Filters
  class AppuntoFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = [terms_summary, statuses_summary, state_summary].compact
        parts.any? ? parts.to_sentence : "Tutti gli appunti"
      end

      private

      def terms_summary
        if terms.any?
          "\"#{terms.join(', ')}\""
        end
      end

      def statuses_summary
        if statuses.any?
          statuses.count == 1 ? statuses.first : "#{statuses.count} stati"
        end
      end

      def state_summary
        if state.present?
          ::AppuntoFilter::FIZZY_STATES[state]
        end
      end
    end
  end
end
