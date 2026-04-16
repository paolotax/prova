module Filters
  class TappaFilter < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        :search,
        :filter,
        :scuola_id,
        :giro_id,
        :data_inizio,
        :data_fine,
        :area,
        :giorno,
        :week_offset,
        :sort,
        giro_ids: []
      ].freeze

      class_methods do
        def default_values
          {}
        end
      end

      included do
        store_accessor :fields,
          :search, :filter, :scuola_id, :giro_id, :giro_ids,
          :data_inizio, :data_fine, :area, :giorno, :week_offset, :sort

        %i[search filter scuola_id giro_id data_inizio data_fine
           area giorno week_offset sort].each do |attr|
          define_method(attr) { super().presence }
          define_method("#{attr}=") { |v| super(v.presence) }
        end

        def giro_ids
          Array(super).reject(&:blank?).map(&:to_i)
        end

        def giro_ids=(value)
          super(Array(value).reject(&:blank?).map(&:to_s))
        end
      end

      def as_params
        @as_params ||= {
          search: search,
          filter: filter,
          scuola_id: scuola_id,
          giro_id: giro_id,
          giro_ids: giro_ids,
          data_inizio: data_inizio,
          data_fine: data_fine,
          area: area,
          giorno: giorno,
          week_offset: week_offset,
          sort: sort
        }.compact_blank
      end
    end
  end
end
