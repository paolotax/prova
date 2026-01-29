# frozen_string_literal: true

module StatScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_stat
  end

  private

  def set_stat
    @stat = Stat.find(params[:stat_id])
  end
end
