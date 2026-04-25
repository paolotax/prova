# frozen_string_literal: true

class Dashboard::Columns::ClosedsController < ApplicationController
  include ScopesOwnTappe

  def show
    set_page_and_extract_portion_from filter_own_tappe(
      current_account.entries
                     .published
                     .closed
                     .includes(:goldness, :closure, :not_now)
                     .with_golden_first
                     .recently_closed_first
    )
    Entry.load_entryables(@page.records)
  end
end
