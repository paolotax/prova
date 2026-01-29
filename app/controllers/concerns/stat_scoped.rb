# frozen_string_literal: true

module StatScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_stat
  end

  private

  def set_stat
    # Support both nested resource route (stat_id) and member route (id)
    stat_id = params[:stat_id] || params[:id]
    @stat = Stat.find(stat_id)
  end
end
