# PORO per gestire i filtri appunti (senza persistenza DB)
class AppuntoFilter
  attr_accessor :terms, :statuses, :states

  def initialize(params = {})
    @terms = Array(params[:terms]).filter(&:present?)
    @statuses = Array(params[:statuses]).filter(&:present?)
    @states = Array(params[:states]).filter(&:present?)
  end

  def self.from_params(params)
    new(params)
  end

  def appunti(base_scope)
    result = base_scope
    result = result.search_all_word(terms.first) if terms.present?
    result = result.where(stato: statuses) if statuses.present?
    result = result.with_any_state(states) if states.present?
    result
  end

  def as_params
    {}.tap do |params|
      params[:terms] = terms if terms.present?
      params[:statuses] = statuses if statuses.present?
      params[:states] = states if states.present?
    end
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

  def empty?
    terms.blank? && statuses.blank? && states.blank?
  end
end
