class DragDropCoverComponent < ViewComponent::Base
  def initialize(libro:)
    @libro = libro
  end

  private

  attr_reader :libro
end 