# == Schema Information
#
# Table name: filters
#
#  id            :uuid             not null, primary key
#  fields        :jsonb
#  params_digest :string
#  type          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid
#  creator_id    :bigint
#
# Indexes
#
#  index_filters_on_account_id              (account_id)
#  index_filters_on_creator_id              (creator_id)
#  index_filters_on_type_and_params_digest  (type,params_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (creator_id => users.id)
#
require "test_helper"

module Filters
  class TappaFilterTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :scuole

    setup do
      @fizzy  = accounts(:fizzy)
      @user   = users(:one)
      @scuola = scuole(:scuola_fizzy)
      Current.account = @fizzy
      Current.user = @user

      @t_oggi   = @user.tappe.create!(tappable: @scuola, data_tappa: Date.current)
      @t_domani = @user.tappe.create!(tappable: @scuola, data_tappa: Date.tomorrow)
      @t_nulla  = @user.tappe.create!(tappable: @scuola, data_tappa: nil)
    end

    teardown { Current.reset }

    test "results returns all user tappe when no filter given" do
      filter = TappaFilter.from_params({})
      assert_equal 3, filter.results(@user.tappe).count
    end

    test "filter 'oggi' returns only today's tappe" do
      filter = TappaFilter.from_params(filter: "oggi")
      result = filter.results(@user.tappe)
      assert_includes result, @t_oggi
      assert_not_includes result, @t_domani
    end

    test "filter 'da_programmare' returns tappe without data_tappa" do
      filter = TappaFilter.from_params(filter: "da_programmare")
      result = filter.results(@user.tappe)
      assert_includes result, @t_nulla
      assert_not_includes result, @t_oggi
    end

    test "scuola_id narrows to one school" do
      other_scuola = Scuola.create!(account: @fizzy, denominazione: "Other", codice_ministeriale: "ZZZ999")
      other_tappa  = @user.tappe.create!(tappable: other_scuola, data_tappa: Date.current)

      filter = TappaFilter.from_params(scuola_id: other_scuola.id)
      result = filter.results(@user.tappe)
      assert_includes result, other_tappa
      assert_not_includes result, @t_oggi
    end
  end
end
