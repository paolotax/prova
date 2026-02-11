class EditorePolicy < ApplicationPolicy
  
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.joins(:mandati).where(mandati: { account_id: Current.account&.id })
      end
    end
  end

  def index?
    true
  end
end
