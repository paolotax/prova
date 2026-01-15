# PORO presenter per gestire lo stato UI dei filtri appunti
class AppuntoFiltering
  attr_reader :user, :filter, :expanded

  def initialize(user, filter, expanded: false)
    @user = user
    @filter = filter
    @expanded = expanded
  end

  def expanded?
    expanded || filters_active?
  end

  def statuses_disponibili
    Appunto::STATO_APPUNTI
  end

  def states_disponibili
    Appunto::FIZZY_STATES
  end

  def show_statuses?
    true
  end

  def show_states?
    true
  end

  def filters_active?
    filter.terms.present? || filter.statuses.present? || filter.states.present?
  end

  def cache_key
    [
      "appunto_filtering",
      user.id,
      filter.as_params.to_json,
      expanded
    ].join("/")
  end
end
