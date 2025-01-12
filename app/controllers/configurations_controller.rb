#---
# Excerpted from "Hotwire Native for Rails Developers",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/jmnative for more book information.
#---
class ConfigurationsController < ApplicationController
  def ios_v1
    render json: {
      settings: {},
      rules: [
        {
          patterns: [
            "/users/sign_in$",
            "/users/sign_up$",
            "/new$",
            "/edit$"
          ],
          properties: {
            context: "modal"
          }
        },
        {
          patterns: [
            "/hikes/[0-9]+/map"
          ],
          properties: {
            view_controller: "map"
          },
        },
        {
          patterns: [
            "refresh_historical_location"
          ],
          properties: {
            presentation: "refresh"
          }
        }
      ]
    }
  end

  def android_v1
    render json: {
      settings: {},
      rules: [
        {
          patterns: [
            ".*"
          ],
          properties: {
            uri: "hotwire://fragment/web",
            pull_to_refresh_enabled: true
          }
        },
        {
          patterns: [
            "/new$",
            "/edit$"
          ],
          properties: {
            context: "modal",
            pull_to_refresh_enabled: false
          }
        },
        {
          patterns: [
            "/hikes/[0-9]+/map"
          ],
          properties: {
            uri: "hotwire://fragment/map",
            title: "Map"
          }
        }
      ]
    }
  end
end
