# frozen_string_literal: true

class Dashboard::Columns::PostponedsController < ApplicationController
  def show
    set_page_and_extract_portion_from current_account.entries
                                                      .non_ssk
                                                      .postponed
                                                      .includes(:goldness, :closure, :not_now)
                                                      .recent
  end
end
