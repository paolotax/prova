module ScuolaFilter::Params
  extend ActiveSupport::Concern

  PERMITTED_PARAMS = [
    :sorted_by,
    :appunti_filter,
    :adozioni_filter,
    comuni: [],
    terms: []
  ].freeze

  class_methods do
    def find_by_params(params)
      find_by params_digest: digest_params(params)
    end

    def digest_params(params)
      Digest::MD5.hexdigest normalize_params(params).to_json
    end

    def normalize_params(params)
      params
        .to_h
        .compact_blank
        .reject(&method(:default_value?))
        .collect { |name, value| [ name, value.is_a?(Array) ? value.collect(&:to_s) : value.to_s ] }
        .sort_by { |name, _| name.to_s }
        .to_h
    end

    def from_params(params)
      find_by_params(params) || build(params)
    end

    def build(params)
      new.tap do |filter|
        params.each do |key, value|
          filter.public_send("#{key}=", value) if filter.respond_to?("#{key}=")
        end
      end
    end

    def remember(attrs)
      create!(attrs)
    rescue ActiveRecord::RecordNotUnique
      find_by_params(attrs).tap(&:touch)
    end
  end

  included do
    before_save { self.params_digest = self.class.digest_params(as_params) }
  end

  def as_params
    @as_params ||= {}.tap do |params|
      params[:sorted_by] = sorted_by
      params[:terms] = terms
      params[:comuni] = comuni
      params[:appunti_filter] = appunti_filter
      params[:adozioni_filter] = adozioni_filter
    end.compact_blank.reject { |k, v| self.class.default_value?(k, v) }
  end

  def as_params_without(key, value)
    as_params.dup.tap do |params|
      if params[key].is_a?(Array)
        params[key] = params[key] - [ value ]
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
end
