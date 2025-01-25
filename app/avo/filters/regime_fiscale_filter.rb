module Avo
  module Filters
    class RegimeFiscaleFilter < Avo::Filters::SelectFilter
      self.name = "Regime Fiscale"

      def apply(request, query, value)
        query.where(regime_fiscale: value)
      end

      def options
        Azienda.regime_fiscales.map { |k, v| [k.titleize, k] }.to_h
      end
    end
  end
end 