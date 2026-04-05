# Account Invitations — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow the global admin to create a new account for someone by entering their email, automatically creating user + account + owner membership and sending a magic link invitation.

**Architecture:** New `Admin::AccountInvitationsController` (index + create) following the same pattern as `Admin::CliMailsController`. Reuses existing `MagicLinkMailer#invitation` and magic link system. Adds validation: one account per user (for now).

**Tech Stack:** Rails controller, existing MagicLink model, existing MagicLinkMailer, admin layout

---

### Task 1: Controller — `Admin::AccountInvitationsController`

**Files:**
- Create: `app/controllers/admin/account_invitations_controller.rb`

**Step 1: Create the controller**

```ruby
class Admin::AccountInvitationsController < Admin::BaseController
  def index
    @invitations = User.joins(:memberships)
      .where(memberships: { role: :owner })
      .includes(:accounts)
      .order(created_at: :desc)
  end

  def create
    email = params[:email]&.strip&.downcase

    if email.blank?
      redirect_to admin_account_invitations_path, alert: "Inserisci un'email"
      return
    end

    user = User.find_or_initialize_by(email: email)

    if user.persisted? && user.accounts.any?
      redirect_to admin_account_invitations_path, alert: "#{email} ha già un account"
      return
    end

    if user.new_record?
      base_name = email.split("@").first
      user.name = if User.exists?(name: base_name)
        "#{base_name}-#{SecureRandom.hex(3)}"
      else
        base_name
      end
      user.save!
    end

    account = Account.create!(name: user.name)
    account.memberships.create!(user: user, role: :owner)

    user.magic_links.where(purpose: :sign_in).valid.update_all(expires_at: Time.current)
    magic_link = user.magic_links.create!(purpose: :sign_in)
    MagicLinkMailer.invitation(user, magic_link, account).deliver_later

    redirect_to admin_account_invitations_path, notice: "Account creato e invito inviato a #{email}"
  end
end
```

**Step 2: Verify it inherits from `Admin::BaseController`** (gets `require_superadmin!` and `layout "admin"` for free)

---

### Task 2: Route

**Files:**
- Modify: `config/routes.rb:64-68` (inside `namespace :admin`)

**Step 1: Add the route**

Change:

```ruby
    namespace :admin do
      root 'dashboard#index'
      resources :extension_mails, only: %i[index create]
      resources :cli_mails, only: %i[index create]
    end
```

To:

```ruby
    namespace :admin do
      root 'dashboard#index'
      resources :extension_mails, only: %i[index create]
      resources :cli_mails, only: %i[index create]
      resources :account_invitations, only: %i[index create]
    end
```

---

### Task 3: View — `index.html.erb`

**Files:**
- Create: `app/views/admin/account_invitations/index.html.erb`

**Step 1: Create the view**

```erb
<h2>Invita nuovo account</h2>

<%= form_with url: admin_account_invitations_path, method: :post, style: "margin-bottom: 2rem; display: flex; gap: 0.5rem; align-items: end;" do |f| %>
  <div>
    <label for="email" style="display: block; font-size: 0.875rem; margin-bottom: 0.25rem; color: var(--color-ink-dark);">Email</label>
    <%= f.email_field :email, placeholder: "nome@esempio.it", required: true, class: "input", style: "width: 320px;" %>
  </div>
  <%= f.submit "Crea account e invia invito", class: "btn btn--primary" %>
<% end %>

<h3>Account creati</h3>
<table style="width: 100%; border-collapse: collapse;">
  <thead>
    <tr style="border-bottom: 2px solid var(--color-ink-lighter); text-align: left;">
      <th style="padding: 0.5rem;">Nome</th>
      <th style="padding: 0.5rem;">Email</th>
      <th style="padding: 0.5rem;">Account</th>
      <th style="padding: 0.5rem;">Creato</th>
    </tr>
  </thead>
  <tbody>
    <% @invitations.each do |user| %>
      <tr style="border-bottom: 1px solid var(--color-ink-lighter);">
        <td style="padding: 0.5rem;"><%= user.name %></td>
        <td style="padding: 0.5rem; color: var(--color-ink-dark);"><%= user.email %></td>
        <td style="padding: 0.5rem;"><%= user.accounts.map(&:name).join(", ") %></td>
        <td style="padding: 0.5rem; color: var(--color-ink-dark);"><%= l(user.created_at, format: :short) %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

---

### Task 4: Update admin dashboard nav

**Files:**
- Modify: `app/views/layouts/admin.html.erb:19-22` (nav section)
- Modify: `app/views/admin/dashboard/index.html.erb` (add link to tools list)

**Step 1: Add nav link**

In `app/views/layouts/admin.html.erb`, add to the nav:

```erb
<%= link_to "Inviti Account", admin_account_invitations_path, style: "color: var(--color-link);" %>
```

**Step 2: Add to dashboard tools list**

In `app/views/admin/dashboard/index.html.erb`, add to the `<ul>`:

```erb
<li style="margin-bottom: 0.5rem;">
  <%= link_to admin_account_invitations_path, style: "color: var(--color-link); font-size: 1rem;" do %>
    Invita nuovo account
  <% end %>
</li>
```

---

### Task 5: Test

**Files:**
- Create: `test/controllers/admin/account_invitations_controller_test.rb`

**Step 1: Write the test**

```ruby
require "test_helper"

class Admin::AccountInvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
  end

  test "index shows invitation form" do
    get admin_account_invitations_path
    assert_response :success
  end

  test "create creates user, account, membership and sends invitation" do
    assert_difference ["User.count", "Account.count", "Accounts::Membership.count"], 1 do
      post admin_account_invitations_path, params: { email: "nuovo@example.com" }
    end

    user = User.find_by(email: "nuovo@example.com")
    assert user.present?
    assert_equal 1, user.accounts.count
    assert user.memberships.first.owner?
    assert_redirected_to admin_account_invitations_path
  end

  test "create rejects user who already has an account" do
    existing = users(:paolo)

    assert_no_difference ["Account.count"] do
      post admin_account_invitations_path, params: { email: existing.email }
    end

    assert_redirected_to admin_account_invitations_path
    assert_match /già un account/, flash[:alert]
  end

  test "non-admin cannot access" do
    sign_in_as(users(:paolo))
    get admin_account_invitations_path
    assert_redirected_to root_path
  end
end
```

**Step 2: Run tests**

```bash
docker exec prova-app-1 bin/rails test test/controllers/admin/account_invitations_controller_test.rb
```

Note: test helper `sign_in_as` and fixtures need to match existing test setup. Check `test/test_helper.rb` for the sign-in helper and `test/fixtures/users.yml` for an admin user fixture.

---

### Task 6: Commit

```bash
git add app/controllers/admin/account_invitations_controller.rb \
        app/views/admin/account_invitations/index.html.erb \
        app/views/layouts/admin.html.erb \
        app/views/admin/dashboard/index.html.erb \
        config/routes.rb \
        test/controllers/admin/account_invitations_controller_test.rb
git commit -m "feat: admin account invitations — create account + send magic link"
```
