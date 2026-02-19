# frozen_string_literal: true

class Dashboard::Columns::ClosedsController < ApplicationController
  def show
    set_page_and_extract_portion_from current_account.entries
                                                      .published
                                                      .closed
                                                      .includes(:goldness, :closure, :not_now)
                                                      .with_golden_first
                                                      .recently_closed_first
    Entry.load_entryables(@page.records)
  end
end
