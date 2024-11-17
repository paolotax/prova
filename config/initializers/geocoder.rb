Geocoder.configure(
  # Geocoding options
  timeout: 10,                 # geocoding service timeout (secs)
  lookup: :mapbox,         # name of geocoding service (symbol)
  ip_lookup: :geoip2,      # name of IP address geocoding service (symbol)
  geoip2: {
    file: "db/geocoder/GeoLite2-City.mmdb"
  },
  language: :en,              # ISO-639 language code
  # use_https: false,           # use HTTPS for lookup requests? (if supported)
  # http_proxy: nil,            # HTTP proxy server (user:pass@host:port)
  # https_proxy: nil,           # HTTPS proxy server (user:pass@host:port)
  api_key: Rails.application.credentials.dig(:mapkick, :mapbox_access_token),               # API key for geocoding service
  # cache: nil,                 # cache object (must respond to #[], #[]=, and #del)

  # Exceptions that should not be rescued by default
  # (if you want to implement custom error handling);
  # supports SocketError and Timeout::Error
  # always_raise: [],

  # Calculation options
  units: :km,                 # :km for kilometers or :mi for miles
  distances: :linear,          # :spherical or :linear

  # Cache configuration
  # cache_options: {
  #   expiration: 2.days,
  #   prefix: 'geocoder:'
  # }
  # 
  
  # caching (see Caching section below for details):
  cache: Redis.new,
  cache_options: {
    expiration: 2.days, # Defaults to `nil`
    prefix: "another_key:" # Defaults to `geocoder:`
  }


)
