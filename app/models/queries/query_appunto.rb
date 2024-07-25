class Queries::QueryAppunto
  def self.call(base_relation, params)
    new(base_relation, params).call
  end

  def initialize(base_relation, params)
    @base_relation = base_relation
    @params = params
  end

  def call
    # do the work
  end

  private

    attr_reader :base_relation, :params
end