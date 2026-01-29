# frozen_string_literal: true

class StatPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(visible: true)
      end
    end
  end

  def index?
    true
  end

  def show?
    user.admin? || record.visible?
  end

  def create?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy?
    user.admin?
  end

  # Custom action for executing stats
  def execute?
    user.admin? || record.visible?
  end
end
