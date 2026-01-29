module FilterScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_filter, only: [:index]
    before_action :set_user_filtering, only: [:index]
  end

  private

  def set_filter
    if params[:filter_id].present?
      @filter = Current.user.filters.find(params[:filter_id])
    else
      @filter = filter_class.from_params(filter_params)
    end
  end

  def set_user_filtering
    @user_filtering = filtering_class.new(Current.user, @filter, expanded: expanded_param)
  end

  # Convention: AppuntiController -> Filters::Appunto
  # Convention: ScuoleController -> Filters::Scuola
  def filter_class
    "Filters::#{controller_name.classify.singularize}Filter".constantize
  end

  # Convention: AppuntiController -> Filters::Appunto::Filtering ecc...
  def filtering_class
    "Filters::#{controller_name.classify.singularize}Filter::Filtering".constantize
  end

  def filter_params
    params.permit(*self.class::FILTER_PARAMS)
  end

  def expanded_param
    ActiveRecord::Type::Boolean.new.cast(params[:expand_all])
  end
end
