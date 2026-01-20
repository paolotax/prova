# frozen_string_literal: true

class Dashboard::Columns::ClosedsController < ApplicationController
  def show
    set_page_and_extract_portion_from current_account.entries
                                                      .closed
                                                      .includes(:goldness, :closure, :not_now)
                                                      .recently_closed_first
  end
end
