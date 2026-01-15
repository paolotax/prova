# == Schema Information
#
# Table name: filters
#
#  id            :uuid             not null, primary key
#  fields        :jsonb
#  params_digest :string
#  type          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid
#  creator_id    :bigint
#
# Indexes
#
#  index_filters_on_account_id              (account_id)
#  index_filters_on_creator_id              (creator_id)
#  index_filters_on_type_and_params_digest  (type,params_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (creator_id => users.id)
#
module Filters
  class Base < ApplicationRecord
    self.table_name = "filters"

    belongs_to :creator, class_name: "User", default: -> { Current.user }
    belongs_to :account, default: -> { Current.account }

    # STI: trova record per params normalizzati
    def self.from_params(params)
      find_by_params(params) || build_from_params(params)
    end

    def self.find_by_params(params)
      find_by(params_digest: digest_params(params))
    end

    def self.digest_params(params)
      Digest::MD5.hexdigest(normalize_params(params).to_json)
    end

    def self.normalize_params(params)
      params
        .to_h
        .compact_blank
        .reject { |k, v| default_value?(k, v) }
        .transform_values { |v| v.is_a?(Array) ? v.map(&:to_s) : v.to_s }
        .sort_by { |k, _| k.to_s }
        .to_h
    end

    def self.build_from_params(params)
      new.tap do |filter|
        params.each do |key, value|
          filter.public_send("#{key}=", value) if filter.respond_to?("#{key}=")
        end
      end
    end

    def self.default_values
      {}
    end

    def self.default_value?(key, value)
      default_values[key.to_sym].eql?(value)
    end

    def self.remember(attrs)
      create!(attrs)
    rescue ActiveRecord::RecordNotUnique
      find_by_params(attrs).tap(&:touch)
    end

    before_save { self.params_digest = self.class.digest_params(as_params) }

    # Da implementare nelle sottoclassi
    def results
      raise NotImplementedError, "Sottoclasse deve implementare #results"
    end

    def as_params
      raise NotImplementedError, "Sottoclasse deve implementare #as_params"
    end

    def as_params_without(key, value)
      as_params.dup.tap do |params|
        if params[key].is_a?(Array)
          params[key] = params[key] - [value]
          params.delete(key) if params[key].empty?
        elsif params[key] == value
          params.delete(key)
        end
      end
    end

    def params_digest
      super.presence || self.class.digest_params(as_params)
    end

    def empty?
      self.class.normalize_params(as_params).blank?
    end

    def cacheable?
      persisted?
    end

    def cache_key
      ActiveSupport::Cache.expand_cache_key(params_digest, self.class.name.underscore)
    end
  end
end
