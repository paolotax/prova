def next?
  File.basename(__FILE__) == "Gemfile.next"
end
source "https://rubygems.org"

ruby "3.2.2"

gem "rails", "8.0.2"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

gem "tailwindcss-rails"
gem "jbuilder"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 5.1"
gem "sidekiq", "~> 7.2"
gem "sidekiq-scheduler", "~> 6.0"

gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false
gem "image_processing", "~> 1.2"

group :production do
  # Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
  gem "kamal", require: false

  # Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
  gem "thruster", require: false
end


group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
  gem "dotenv"

  # gem 'jupyter_on_rails'#, path: '~/rails_2023/jupyter_on_rails'

  # #  For sessions pick either:
  # gem 'ffi-rzmq'
end

group :development do
  # Use console on exceptions pages          [https://github.com/rails/web-console]
  gem "web-console"

  gem "annotate"
  gem "letter_opener"

  gem "bullet"

  gem "derailed_benchmarks"
  gem "stackprof"

end

group :development, :production do
  gem "rails_performance"
end



group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  gem 'faker'
end



group :development do
  gem "foreman", require: false
  gem "log_bench"
end

gem "scenic", "~> 1.7"
gem "highline", "~> 2.0.3"

gem "money-rails", "~> 1.15"

gem "prawn", "~> 2.4"
gem "prawn-table", "~> 0.2"
gem 'prawn-html'
gem 'prawn-svg'
gem 'prawn-emoji'

gem 'combine_pdf'

gem "pg_search", "~> 2.3"
gem 'activerecord-import'


gem "view_component"

gem "inline_svg"

gem 'caxlsx'
gem 'caxlsx_rails'

gem "aws-sdk-s3", require: false

gem "devise", "~> 4.9"
gem "omniauth-rails_csrf_protection", "~> 1.0"
gem "omniauth-google-oauth2", "~> 1.1"
gem "omniauth-github", "~> 2.0"

gem "devise-i18n"


gem "hotwire_combobox"

gem 'resend', '~> 0.10.0'

# da eliminare
gem "pagy"

gem "geared_pagination", "~> 1.2"

gem "groupdate", "~> 6.4"

gem 'rack-mini-profiler', require: false

gem "mapkick-rb"
gem "geocoder"
gem "maxminddb"

gem "roo", "~> 2.10.0"
gem "roo-xls", "~> 1.0"

gem 'smarter_csv'

gem "acts_as_list"


source "https://cGFvbG8udGFzc2luYXJpQGhleS5jb20@get.railsdesigner.com/private" do
  gem "rails_designer", "~> 1.12.0"
end

gem "wicked", "~> 2.0"

gem "awesome_back_url"

gem "ranked-model", "~> 0.4.10"

gem "counter_culture", "~> 3.8"

gem "positioning"

gem 'avo'
gem "ransack"

gem "pundit"

gem "rack-attack"

gem "ahoy_matey"


gem "friendly_id", "~> 5.5"

gem "blazer", "~> 3.1"

gem "ruby-openai"

gem "streamio-ffmpeg"

gem "fuzzy_match"

gem 'nokogiri'
gem 'open-uri'

gem 'rqrcode'

# gem 'rails_icons'

gem "reactionview", "~> 0.1.2"

