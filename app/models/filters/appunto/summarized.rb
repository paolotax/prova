module Filters
  class Appunto < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = [terms_summary, statuses_summary, states_summary].compact
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

      def states_summary
        if states.any?
          labels = states.map { |s| ::Appunto::FIZZY_STATES[s] }.compact
          labels.count == 1 ? labels.first : "#{labels.count} filtri"
        end
      end
    end
  end
end
