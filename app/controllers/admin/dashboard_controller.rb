class Admin::DashboardController < Admin::BaseController
  def index
    @users_count = User.count
    @accounts_count = Account.count
  end
end
