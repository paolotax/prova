class EditorePolicy < ApplicationPolicy
  
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.miei_editori(user)
      end
    end
  end

  def index?
    true
  end
end
