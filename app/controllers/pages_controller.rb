class PagesController < ApplicationController

    def index 
        # redis = Redis.new(host: "redis", port: 6379)
        # redis.incr "page_hits"
        # @page_hits = redis.get "page_hits"
        @page_hits = 2345
        @totale_scuole = ImportScuola.count
        @totale_adozioni = ImportAdozione.count

        @scuole_e_adozioni_per_regione = ImportScuola.joins(:import_adozioni)
                            .select('"import_scuole"."REGIONE", count(DISTINCT import_scuole.id) nr_scuole, count(import_adozioni.id) nr_adozioni')
                            .group(:REGIONE)

    end
end
