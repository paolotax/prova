# frozen_string_literal: true

class Dashboard::Columns::PostponedsController < ApplicationController
  include ScopesOwnTappe

  def show
    set_page_and_extract_portion_from filter_own_tappe(
      current_account.entries
                     .published
                     .postponed
                     .includes(:goldness, :closure, :not_now)
                     .with_golden_first
                     .recent
    )
    Entry.load_entryables(@page.records)
  end
end
