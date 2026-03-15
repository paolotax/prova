class Appunti::BozzeController < ApplicationController
  before_action :authenticate_user!

  def index
    @bozze = current_account.appunti.drafted
               .where(user: current_user)
               .with_rich_text_content
               .order(created_at: :desc)
               .limit(10)

    render layout: !turbo_frame_request?
  end
end
