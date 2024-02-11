class PagesController < ApplicationController

    def index 
        # redis = Redis.new(host: "redis", port: 6379)
        # redis.incr "page_hits"
        # @page_hits = redis.get "page_hits"
        @page_hits = 2345
        @totale_scuole = ImportScuola.count
        @totale_adozioni = ImportAdozione.count

    end
end
