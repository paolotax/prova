# Passwordless Authentication Migration Plan

## Overview

Migrate from Devise (6 modules, ~2000 lines of gem code) to custom passwordless authentication (~150 lines of application code) while maintaining zero downtime and full backward compatibility during transition.

## Current State

- **Devise modules:** database_authenticatable, registerable, recoverable, rememberable, validatable, confirmable
- **Login methods:** Username OR email + password
- **Protection:** Turnstile CAPTCHA on registration
- **Multi-tenancy:** Account/Membership with Current attributes
- **Authorization:** Pundit policies

## Target State

- **Authentication:** Magic links sent via email
- **Sessions:** Explicit Session model with token-based auth
- **OAuth:** Google/GitHub as alternative sign-in methods
- **Protection:** Turnstile CAPTCHA on magic link requests
- **Multi-tenancy:** Preserved with Current.session added

## Migration Phases

---

## Phase 1: Foundation (No Breaking Changes)

### 1.1 Create Session Model

**Migration:**
```ruby
# db/migrate/XXXXXX_create_sessions.rb
class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: false, type: :bigint
      t.references :account, foreign_key: false, type: :uuid
      t.string :token, null: false, index: { unique: true }
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_active_at
      t.timestamps
    end

    add_index :sessions, :user_id
    add_index :sessions, [:user_id, :last_active_at]
  end
end
```

**Model:**
```ruby
# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :user
  belongs_to :account, optional: true

  before_create :set_token

  scope :active, -> { where("last_active_at > ?", 30.days.ago) }
  scope :expired, -> { where("last_active_at <= ?", 30.days.ago) }

  def touch_last_active
    update_column(:last_active_at, Time.current) if last_active_at < 1.hour.ago
  end

  def expired?
    last_active_at.nil? || last_active_at <= 30.days.ago
  end

  def revoke!
    destroy!
  end

  private

  def set_token
    self.token = SecureRandom.urlsafe_base64(32)
    self.last_active_at = Time.current
  end
end
```

**User association:**
```ruby
# app/models/user.rb (add to existing)
has_many :sessions, dependent: :destroy

def revoke_all_sessions!
  sessions.destroy_all
end

def revoke_other_sessions!(current_session)
  sessions.where.not(id: current_session.id).destroy_all
end
```

**Update Current:**
```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account, :membership, :session, :request_id

  def authenticated?
    user.present?
  end

  def member?
    membership.present?
  end

  def admin?
    membership&.admin? || membership&.owner?
  end

  def owner?
    membership&.owner?
  end
end
```

### 1.2 Create MagicLink Model

**Migration:**
```ruby
# db/migrate/XXXXXX_create_magic_links.rb
class CreateMagicLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :magic_links, id: :uuid do |t|
      t.references :user, null: false, foreign_key: false, type: :bigint
      t.string :token, null: false, index: { unique: true }
      t.string :purpose, null: false, default: 'sign_in'
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.string :ip_address
      t.timestamps
    end

    add_index :magic_links, [:user_id, :purpose]
    add_index :magic_links, :expires_at
  end
end
```

**Model:**
```ruby
# app/models/magic_link.rb
class MagicLink < ApplicationRecord
  belongs_to :user

  enum :purpose, { sign_in: "sign_in", email_verification: "email_verification" }

  before_create :set_token_and_expiry

  scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def used?
    used_at.present?
  end

  def valid_for_use?
    !expired? && !used?
  end

  def mark_as_used!
    update!(used_at: Time.current)
  end

  def self.cleanup_expired
    expired.delete_all
  end

  private

  def set_token_and_expiry
    self.token = SecureRandom.urlsafe_base64(32)
    self.expires_at = 15.minutes.from_now
  end
end
```

**User association:**
```ruby
# app/models/user.rb (add to existing)
has_many :magic_links, dependent: :destroy

def send_magic_link!(purpose: :sign_in, ip_address: nil)
  # Invalidate previous magic links for same purpose
  magic_links.where(purpose: purpose).valid.update_all(expires_at: Time.current)

  magic_link = magic_links.create!(purpose: purpose, ip_address: ip_address)
  MagicLinkMailer.sign_in(self, magic_link).deliver_later
  magic_link
end
```

### 1.3 Add Feature Flag

**Migration:**
```ruby
# db/migrate/XXXXXX_add_passwordless_to_users.rb
class AddPasswordlessToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :passwordless_enabled, :boolean, default: false, null: false
  end
end
```

**Application config:**
```ruby
# config/initializers/passwordless.rb
Rails.application.config.passwordless = ActiveSupport::OrderedOptions.new
Rails.application.config.passwordless.enabled = ENV.fetch("PASSWORDLESS_AUTH_ENABLED", "false") == "true"
Rails.application.config.passwordless.magic_link_expiry = 15.minutes
Rails.application.config.passwordless.session_expiry = 30.days
```

### 1.4 Tests for Phase 1

```ruby
# test/models/session_test.rb
require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "generates unique token on create" do
    user = users(:alice)
    session = user.sessions.create!

    assert session.token.present?
    assert_equal 43, session.token.length # base64 of 32 bytes
  end

  test "tracks last active time" do
    session = sessions(:alice_session)
    old_time = session.last_active_at

    travel 2.hours do
      session.touch_last_active
      assert session.last_active_at > old_time
    end
  end

  test "identifies expired sessions" do
    session = sessions(:alice_session)

    assert_not session.expired?

    travel 31.days do
      assert session.expired?
    end
  end

  test "revokes session" do
    session = sessions(:alice_session)
    session.revoke!

    assert_raises(ActiveRecord::RecordNotFound) { session.reload }
  end
end

# test/models/magic_link_test.rb
require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  test "generates token and expiry on create" do
    user = users(:alice)
    magic_link = user.magic_links.create!(purpose: :sign_in)

    assert magic_link.token.present?
    assert magic_link.expires_at > Time.current
    assert magic_link.expires_at < 20.minutes.from_now
  end

  test "valid_for_use? returns false when expired" do
    magic_link = magic_links(:alice_sign_in)

    assert magic_link.valid_for_use?

    travel 20.minutes do
      assert_not magic_link.valid_for_use?
    end
  end

  test "valid_for_use? returns false when already used" do
    magic_link = magic_links(:alice_sign_in)
    magic_link.mark_as_used!

    assert_not magic_link.valid_for_use?
  end

  test "invalidates previous magic links on new request" do
    user = users(:alice)
    old_link = user.magic_links.create!(purpose: :sign_in)

    user.send_magic_link!
    old_link.reload

    assert old_link.expired?
  end
end
```

**Fixtures:**
```yaml
# test/fixtures/sessions.yml
alice_session:
  user: alice
  token: <%= SecureRandom.urlsafe_base64(32) %>
  last_active_at: <%= 1.hour.ago %>
  created_at: <%= 1.day.ago %>
  updated_at: <%= 1.hour.ago %>

bob_session:
  user: bob
  token: <%= SecureRandom.urlsafe_base64(32) %>
  last_active_at: <%= 2.days.ago %>
  created_at: <%= 7.days.ago %>
  updated_at: <%= 2.days.ago %>

# test/fixtures/magic_links.yml
alice_sign_in:
  user: alice
  token: <%= SecureRandom.urlsafe_base64(32) %>
  purpose: sign_in
  expires_at: <%= 10.minutes.from_now %>
  created_at: <%= 5.minutes.ago %>
  updated_at: <%= 5.minutes.ago %>
```

---

## Phase 2: Passwordless Controllers & Views

### 2.1 Magic Link Mailer

```ruby
# app/mailers/magic_link_mailer.rb
class MagicLinkMailer < ApplicationMailer
  def sign_in(user, magic_link)
    @user = user
    @magic_link = magic_link
    @sign_in_url = verify_magic_link_url(token: magic_link.token)

    mail(
      to: user.email,
      subject: "Il tuo link per accedere a #{app_name}"
    )
  end

  private

  def app_name
    "Prova"
  end
end
```

**View:**
```erb
<%# app/views/magic_link_mailer/sign_in.html.erb %>
<%= render Email::LayoutComponent.new do %>
  <%= render Email::HeadingComponent.new(text: "Accedi al tuo account") %>

  <%= render Email::TextComponent.new do %>
    Ciao <%= @user.name %>,
  <% end %>

  <%= render Email::TextComponent.new do %>
    Clicca il pulsante qui sotto per accedere al tuo account.
    Questo link scade tra 15 minuti.
  <% end %>

  <%= render Email::ButtonComponent.new(
    text: "Accedi ora",
    url: @sign_in_url
  ) %>

  <%= render Email::TextComponent.new(size: :small, color: :muted) do %>
    Se non hai richiesto questo link, puoi ignorare questa email.
  <% end %>
<% end %>
```

```text
<%# app/views/magic_link_mailer/sign_in.text.erb %>
Ciao <%= @user.name %>,

Clicca questo link per accedere al tuo account:
<%= @sign_in_url %>

Questo link scade tra 15 minuti.

Se non hai richiesto questo link, puoi ignorare questa email.
```

### 2.2 Magic Links Controller

```ruby
# app/controllers/magic_links_controller.rb
class MagicLinksController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :redirect_if_authenticated, only: [:new, :create]
  before_action :verify_turnstile, only: :create

  def new
    # Sign in form - just email input
  end

  def create
    user = User.find_by(email: params[:email]&.downcase&.strip)

    if user
      user.send_magic_link!(ip_address: request.remote_ip)
    end

    # Always show same message to prevent email enumeration
    redirect_to magic_link_sent_path, notice: "Se l'email esiste, riceverai un link per accedere."
  end

  def sent
    # Confirmation page shown after requesting magic link
  end

  def verify
    magic_link = MagicLink.valid.find_by(token: params[:token])

    if magic_link&.valid_for_use?
      user = magic_link.user
      session = create_session_for(user)
      magic_link.mark_as_used!

      redirect_to after_sign_in_path, notice: "Accesso effettuato!"
    else
      redirect_to new_magic_link_path, alert: "Link non valido o scaduto. Richiedi un nuovo link."
    end
  end

  private

  def redirect_if_authenticated
    redirect_to root_path if current_user
  end

  def create_session_for(user)
    session = user.sessions.create!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    cookies.signed.permanent[:session_token] = {
      value: session.token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }

    Current.user = user
    Current.session = session

    session
  end

  def after_sign_in_path
    stored_location_for(:user) || root_path
  end

  def verify_turnstile
    unless TurnstileVerifier.check(params["cf-turnstile-response"], request.remote_ip)
      redirect_to new_magic_link_path, alert: "Verifica di sicurezza fallita. Riprova."
    end
  end
end
```

### 2.3 Sessions Controller (New)

```ruby
# app/controllers/passwordless/sessions_controller.rb
module Passwordless
  class SessionsController < ApplicationController
    skip_before_action :authenticate_user!, only: [:destroy]
    before_action :set_session, only: [:destroy]

    def index
      @sessions = current_user.sessions.active.order(last_active_at: :desc)
      @current_session = Current.session
    end

    def destroy
      if @session.user == current_user
        @session.revoke!

        if @session == Current.session
          cookies.delete(:session_token)
          redirect_to root_path, notice: "Sei uscito."
        else
          redirect_to sessions_path, notice: "Sessione terminata."
        end
      else
        redirect_to sessions_path, alert: "Non puoi terminare questa sessione."
      end
    end

    def destroy_all
      current_user.revoke_other_sessions!(Current.session)
      redirect_to sessions_path, notice: "Tutte le altre sessioni sono state terminate."
    end

    private

    def set_session
      @session = Session.find(params[:id])
    end
  end
end
```

### 2.4 Views

```erb
<%# app/views/magic_links/new.html.erb %>
<div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full space-y-8">
    <div>
      <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
        Accedi al tuo account
      </h2>
      <p class="mt-2 text-center text-sm text-gray-600">
        Ti invieremo un link magico via email
      </p>
    </div>

    <%= form_with url: magic_links_path, class: "mt-8 space-y-6" do |f| %>
      <div>
        <%= f.label :email, "Indirizzo email", class: "sr-only" %>
        <%= f.email_field :email,
            autofocus: true,
            autocomplete: "email",
            required: true,
            placeholder: "Inserisci la tua email",
            class: "appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-red-500 focus:border-red-500 focus:z-10 sm:text-sm" %>
      </div>

      <div data-controller="turnstile"
           data-turnstile-site-key-value="<%= ENV['TURNSTILE_SITE_KEY'] %>">
        <div data-turnstile-target="widget"></div>
      </div>

      <%= f.submit "Invia link di accesso",
          class: "group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500",
          data: { turnstile_target: "submit", disabled: true } %>
    <% end %>

    <div class="text-center">
      <p class="text-sm text-gray-600">
        Non hai un account?
        <%= link_to "Registrati", new_user_registration_path, class: "font-medium text-red-600 hover:text-red-500" %>
      </p>
    </div>
  </div>
</div>
```

```erb
<%# app/views/magic_links/sent.html.erb %>
<div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full space-y-8 text-center">
    <div>
      <svg class="mx-auto h-16 w-16 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
      </svg>
      <h2 class="mt-6 text-3xl font-extrabold text-gray-900">
        Controlla la tua email
      </h2>
      <p class="mt-2 text-sm text-gray-600">
        Se l'indirizzo email esiste nel nostro sistema, riceverai un link per accedere.
      </p>
      <p class="mt-4 text-sm text-gray-500">
        Il link scade tra 15 minuti.
      </p>
    </div>

    <div class="mt-6">
      <%= link_to "Torna alla pagina di accesso", new_magic_link_path,
          class: "text-red-600 hover:text-red-500" %>
    </div>
  </div>
</div>
```

```erb
<%# app/views/passwordless/sessions/index.html.erb %>
<div class="max-w-4xl mx-auto py-8">
  <h1 class="text-2xl font-bold mb-6">Le tue sessioni attive</h1>

  <div class="bg-white shadow rounded-lg divide-y">
    <% @sessions.each do |session| %>
      <div class="p-4 flex items-center justify-between <%= 'bg-green-50' if session == @current_session %>">
        <div>
          <div class="flex items-center gap-2">
            <% if session == @current_session %>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                Sessione corrente
              </span>
            <% end %>
          </div>
          <p class="text-sm text-gray-600 mt-1">
            <%= session.user_agent&.truncate(50) || "Browser sconosciuto" %>
          </p>
          <p class="text-xs text-gray-500 mt-1">
            IP: <%= session.ip_address || "Sconosciuto" %> &middot;
            Ultima attività: <%= time_ago_in_words(session.last_active_at) %> fa
          </p>
        </div>

        <% unless session == @current_session %>
          <%= button_to "Termina", session_path(session),
              method: :delete,
              class: "text-red-600 hover:text-red-800 text-sm font-medium",
              data: { turbo_confirm: "Sei sicuro di voler terminare questa sessione?" } %>
        <% end %>
      </div>
    <% end %>
  </div>

  <% if @sessions.count > 1 %>
    <div class="mt-6">
      <%= button_to "Termina tutte le altre sessioni", destroy_all_sessions_path,
          method: :delete,
          class: "text-red-600 hover:text-red-800 text-sm font-medium",
          data: { turbo_confirm: "Sei sicuro di voler terminare tutte le altre sessioni?" } %>
    </div>
  <% end %>
</div>
```

### 2.5 Routes

```ruby
# config/routes.rb (add these routes)

# Passwordless authentication
resources :magic_links, only: [:new, :create] do
  collection do
    get :sent
    get :verify, path: "verify/:token"
  end
end

# Session management
resources :sessions, only: [:index, :destroy], controller: "passwordless/sessions" do
  collection do
    delete :destroy_all
  end
end
```

### 2.6 Authentication Concern

```ruby
# app/controllers/concerns/passwordless_authentication.rb
module PasswordlessAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :user_signed_in?
  end

  def current_user
    Current.user ||= authenticate_from_session
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    unless user_signed_in?
      store_location
      redirect_to new_magic_link_path, alert: "Devi accedere per continuare."
    end
  end

  def authenticate_from_session
    return nil unless session_token = cookies.signed[:session_token]

    session = Session.active.find_by(token: session_token)
    return nil unless session

    session.touch_last_active
    Current.session = session
    session.user
  end

  def sign_out_user
    Current.session&.revoke!
    cookies.delete(:session_token)
    Current.user = nil
    Current.session = nil
  end

  def store_location
    session[:return_to] = request.fullpath if request.get?
  end

  def stored_location_for(resource)
    session.delete(:return_to)
  end
end
```

---

## Phase 3: Feature Flag Integration

### 3.1 Update Application Controller

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include PasswordlessAuthentication

  before_action :set_current_request_identifier
  before_action :set_current_user

  # Override authenticate_user! to support both systems during transition
  def authenticate_user!
    if passwordless_auth_enabled?
      super # Uses PasswordlessAuthentication concern
    else
      # Fall back to Devise
      unless current_user
        store_location_for(:user, request.fullpath)
        redirect_to new_user_session_path, alert: "Devi accedere per continuare."
      end
    end
  end

  def current_user
    if passwordless_auth_enabled?
      Current.user ||= authenticate_from_session
    else
      Current.user ||= warden.authenticate(scope: :user)
    end
  end

  private

  def passwordless_auth_enabled?
    Rails.application.config.passwordless.enabled ||
      (current_user&.passwordless_enabled?)
  end

  def set_current_request_identifier
    Current.request_id = request.request_id
  end

  def set_current_user
    Current.user = current_user
  end
end
```

### 3.2 Dual Sign-In Page

```erb
<%# app/views/devise/sessions/new.html.erb (updated) %>
<div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full space-y-8">
    <div>
      <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
        Accedi al tuo account
      </h2>
    </div>

    <%# Passwordless option (promoted) %>
    <div class="bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Accesso senza password</h3>
      <%= form_with url: magic_links_path, class: "space-y-4" do |f| %>
        <div>
          <%= f.email_field :email,
              autofocus: true,
              autocomplete: "email",
              required: true,
              placeholder: "Inserisci la tua email",
              class: "appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-red-500 focus:border-red-500 sm:text-sm" %>
        </div>

        <div data-controller="turnstile"
             data-turnstile-site-key-value="<%= ENV['TURNSTILE_SITE_KEY'] %>">
          <div data-turnstile-target="widget"></div>
        </div>

        <%= f.submit "Invia link di accesso",
            class: "w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500" %>
      <% end %>
    </div>

    <%# Password option (deprecated, collapsible) %>
    <details class="bg-gray-100 rounded-lg">
      <summary class="p-4 cursor-pointer text-sm text-gray-600 hover:text-gray-800">
        Accedi con password (deprecato)
      </summary>
      <div class="p-6 pt-0">
        <%= form_for(resource, as: resource_name, url: session_path(resource_name), class: "space-y-4") do |f| %>
          <div>
            <%= f.text_field :login,
                autofocus: false,
                autocomplete: "username",
                placeholder: "Email o username",
                class: "appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-red-500 focus:border-red-500 sm:text-sm" %>
          </div>

          <div>
            <%= f.password_field :password,
                autocomplete: "current-password",
                placeholder: "Password",
                class: "appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-red-500 focus:border-red-500 sm:text-sm" %>
          </div>

          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <%= f.check_box :remember_me, class: "h-4 w-4 text-red-600 focus:ring-red-500 border-gray-300 rounded" %>
              <%= f.label :remember_me, "Ricordami", class: "ml-2 block text-sm text-gray-900" %>
            </div>

            <%= link_to "Password dimenticata?", new_password_path(resource_name), class: "text-sm text-red-600 hover:text-red-500" %>
          </div>

          <%= f.submit "Accedi",
              class: "w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-gray-600 hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500" %>
        <% end %>
      </div>
    </details>

    <div class="text-center">
      <p class="text-sm text-gray-600">
        Non hai un account?
        <%= link_to "Registrati", new_user_registration_path, class: "font-medium text-red-600 hover:text-red-500" %>
      </p>
    </div>
  </div>
</div>
```

---

## Phase 4: Registration Without Password

### 4.1 Update Registration Flow

```ruby
# app/controllers/passwordless/registrations_controller.rb
module Passwordless
  class RegistrationsController < ApplicationController
    skip_before_action :authenticate_user!
    before_action :redirect_if_authenticated
    before_action :verify_turnstile, only: :create

    def new
      @user = User.new
    end

    def create
      @user = User.new(registration_params)
      @user.password = SecureRandom.hex(32) # Random password (never used)
      @user.passwordless_enabled = true

      if @user.save
        @user.send_magic_link!(purpose: :email_verification, ip_address: request.remote_ip)
        redirect_to magic_link_sent_path, notice: "Controlla la tua email per completare la registrazione."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def registration_params
      params.require(:user).permit(:name, :email)
    end

    def redirect_if_authenticated
      redirect_to root_path if current_user
    end

    def verify_turnstile
      unless TurnstileVerifier.check(params["cf-turnstile-response"], request.remote_ip)
        @user = User.new(registration_params)
        flash.now[:alert] = "Verifica di sicurezza fallita. Riprova."
        render :new, status: :unprocessable_entity
      end
    end
  end
end
```

### 4.2 Registration View

```erb
<%# app/views/passwordless/registrations/new.html.erb %>
<div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full space-y-8">
    <div>
      <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
        Crea il tuo account
      </h2>
      <p class="mt-2 text-center text-sm text-gray-600">
        Nessuna password richiesta - useremo link magici
      </p>
    </div>

    <%= form_with model: @user, url: passwordless_registrations_path, class: "mt-8 space-y-6" do |f| %>
      <% if @user.errors.any? %>
        <div class="bg-red-50 border border-red-200 rounded-md p-4">
          <ul class="list-disc list-inside text-sm text-red-600">
            <% @user.errors.full_messages.each do |message| %>
              <li><%= message %></li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <div class="space-y-4">
        <div>
          <%= f.label :name, "Nome utente", class: "block text-sm font-medium text-gray-700" %>
          <%= f.text_field :name,
              autofocus: true,
              autocomplete: "username",
              required: true,
              class: "mt-1 appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-red-500 focus:border-red-500 sm:text-sm" %>
        </div>

        <div>
          <%= f.label :email, "Email", class: "block text-sm font-medium text-gray-700" %>
          <%= f.email_field :email,
              autocomplete: "email",
              required: true,
              class: "mt-1 appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-red-500 focus:border-red-500 sm:text-sm" %>
        </div>
      </div>

      <div data-controller="turnstile"
           data-turnstile-site-key-value="<%= ENV['TURNSTILE_SITE_KEY'] %>">
        <div data-turnstile-target="widget"></div>
      </div>

      <%= f.submit "Crea account",
          class: "w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500",
          data: { turnstile_target: "submit", disabled: true } %>
    <% end %>

    <div class="text-center">
      <p class="text-sm text-gray-600">
        Hai già un account?
        <%= link_to "Accedi", new_magic_link_path, class: "font-medium text-red-600 hover:text-red-500" %>
      </p>
    </div>
  </div>
</div>
```

### 4.3 Updated Routes

```ruby
# config/routes.rb (add these routes)

namespace :passwordless do
  resources :registrations, only: [:new, :create]
end
```

---

## Phase 5: Session Cleanup Job

```ruby
# app/jobs/cleanup_expired_sessions_job.rb
class CleanupExpiredSessionsJob < ApplicationJob
  queue_as :default

  def perform
    # Clean up expired sessions
    expired_count = Session.expired.delete_all
    Rails.logger.info "Cleaned up #{expired_count} expired sessions"

    # Clean up expired magic links
    links_count = MagicLink.expired.delete_all
    Rails.logger.info "Cleaned up #{links_count} expired magic links"
  end
end
```

**Schedule (add to config/recurring.yml for Solid Queue):**
```yaml
# config/recurring.yml
cleanup_sessions:
  class: CleanupExpiredSessionsJob
  queue: default
  schedule: every day at 3am
```

---

## Phase 6: Remove Devise (Final)

### 6.1 Prerequisites Checklist

Before removing Devise, verify:

- [ ] All users have `passwordless_enabled: true`
- [ ] All active sessions migrated to Session model
- [ ] Magic link sign-in working for 100% of users
- [ ] No password-based sign-ins in last 30 days
- [ ] Registration via passwordless working
- [ ] Session management (view/revoke) working
- [ ] Tests passing without Devise
- [ ] Production monitoring shows no Devise-related errors

### 6.2 Migration to Remove Password Fields

```ruby
# db/migrate/XXXXXX_remove_devise_fields_from_users.rb
class RemoveDeviseFieldsFromUsers < ActiveRecord::Migration[8.0]
  def change
    # Keep these for historical reference but make nullable
    change_column_null :users, :encrypted_password, true

    # Remove Devise-specific columns
    remove_column :users, :reset_password_token, :string
    remove_column :users, :reset_password_sent_at, :datetime
    remove_column :users, :remember_created_at, :datetime
    remove_column :users, :confirmation_token, :string
    remove_column :users, :confirmed_at, :datetime
    remove_column :users, :confirmation_sent_at, :datetime
    remove_column :users, :unconfirmed_email, :string

    # Remove feature flag (no longer needed)
    remove_column :users, :passwordless_enabled, :boolean
  end
end
```

### 6.3 Remove Devise from User Model

```ruby
# app/models/user.rb (final version without Devise)
class User < ApplicationRecord
  include Sluggable

  has_secure_password validations: false # Keep for any legacy password checks

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships

  # ... other associations

  enum :role, { scagnozzo: 0, sbocciatore: 1, omaccio: 2, admin: 3 }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  normalizes :email, with: ->(e) { e.strip.downcase }

  def self.find_by_login(login)
    where("lower(name) = :v OR lower(email) = :v", v: login.downcase).first
  end

  def send_magic_link!(purpose: :sign_in, ip_address: nil)
    magic_links.where(purpose: purpose).valid.update_all(expires_at: Time.current)
    magic_link = magic_links.create!(purpose: purpose, ip_address: ip_address)
    MagicLinkMailer.sign_in(self, magic_link).deliver_later
    magic_link
  end

  def revoke_all_sessions!
    sessions.destroy_all
  end

  def revoke_other_sessions!(current_session)
    sessions.where.not(id: current_session.id).destroy_all
  end

  # Multi-tenancy helpers
  def member_of?(account)
    accounts.include?(account)
  end

  def role_in(account)
    memberships.find_by(account: account)&.role
  end

  def admin_of?(account)
    membership = memberships.find_by(account: account)
    membership&.admin? || membership&.owner?
  end

  def owner_of?(account)
    memberships.find_by(account: account)&.owner?
  end
end
```

### 6.4 Remove Devise Files

```bash
# Files to delete
rm app/models/concerns/authenticable.rb
rm config/initializers/devise.rb
rm -rf app/views/devise/
rm app/controllers/confirmations_controller.rb
rm app/controllers/users/registrations_controller.rb

# Update routes
# Remove: devise_for :users, controllers: { ... }
```

### 6.5 Remove Gems from Gemfile

```ruby
# Remove these lines from Gemfile
# gem "devise", "~> 4.9"
# gem "devise-i18n"

# Keep OmniAuth if using OAuth
# gem "omniauth-rails_csrf_protection", "~> 1.0"
# gem "omniauth-google-oauth2", "~> 1.1"
# gem "omniauth-github", "~> 2.0"
```

### 6.6 Final Routes

```ruby
# config/routes.rb (final authentication routes)
Rails.application.routes.draw do
  # Passwordless authentication
  resources :magic_links, only: [:new, :create] do
    collection do
      get :sent
      get :verify, path: "verify/:token"
    end
  end

  # Session management
  resources :sessions, only: [:index, :destroy], controller: "passwordless/sessions" do
    collection do
      delete :destroy_all
    end
  end

  # Passwordless registration
  namespace :passwordless do
    resources :registrations, only: [:new, :create]
  end

  # OAuth (if keeping)
  # get "/auth/:provider/callback", to: "oauth#callback"
  # get "/auth/failure", to: "oauth#failure"

  # ... rest of routes
end
```

---

## Rollback Plan

If issues arise at any phase:

### Phase 1-3 Rollback
- Set `PASSWORDLESS_AUTH_ENABLED=false`
- All users fall back to Devise
- No data loss

### Phase 4 Rollback
- New registrations use Devise again
- Existing passwordless users continue working
- Add migration to set `passwordless_enabled: false` for affected users

### Phase 6 Rollback (Emergency)
- Restore Devise gem
- Restore devise initializer from git
- Run migration to add back removed columns
- Reset `encrypted_password` for affected users

---

## Timeline Estimate

| Phase | Description | Risk Level |
|-------|-------------|------------|
| Phase 1 | Foundation models | Low |
| Phase 2 | Controllers & views | Low |
| Phase 3 | Feature flag integration | Medium |
| Phase 4 | Passwordless registration | Medium |
| Phase 5 | Session cleanup | Low |
| Phase 6 | Remove Devise | High |

---

## Success Metrics

- [ ] Zero password-related support tickets
- [ ] Sign-in conversion rate maintained or improved
- [ ] Email delivery rate > 99%
- [ ] Magic link click-through rate > 80%
- [ ] Session revocation working correctly
- [ ] No unauthorized access incidents
- [ ] Test coverage maintained at 90%+
- [ ] ~1,800 lines of Devise code removed
- [ ] ~150 lines of custom auth code added

---

## Files Created/Modified Summary

### New Files
- `app/models/session.rb`
- `app/models/magic_link.rb`
- `app/controllers/magic_links_controller.rb`
- `app/controllers/passwordless/sessions_controller.rb`
- `app/controllers/passwordless/registrations_controller.rb`
- `app/controllers/concerns/passwordless_authentication.rb`
- `app/mailers/magic_link_mailer.rb`
- `app/views/magic_links/new.html.erb`
- `app/views/magic_links/sent.html.erb`
- `app/views/magic_link_mailer/sign_in.html.erb`
- `app/views/magic_link_mailer/sign_in.text.erb`
- `app/views/passwordless/sessions/index.html.erb`
- `app/views/passwordless/registrations/new.html.erb`
- `app/jobs/cleanup_expired_sessions_job.rb`
- `config/initializers/passwordless.rb`
- `test/models/session_test.rb`
- `test/models/magic_link_test.rb`
- `test/fixtures/sessions.yml`
- `test/fixtures/magic_links.yml`
- `db/migrate/XXXXXX_create_sessions.rb`
- `db/migrate/XXXXXX_create_magic_links.rb`
- `db/migrate/XXXXXX_add_passwordless_to_users.rb`

### Modified Files
- `app/models/user.rb`
- `app/models/current.rb`
- `app/controllers/application_controller.rb`
- `app/views/devise/sessions/new.html.erb` (during transition)
- `config/routes.rb`

### Deleted Files (Phase 6)
- `app/models/concerns/authenticable.rb`
- `config/initializers/devise.rb`
- `app/views/devise/*`
- `app/controllers/confirmations_controller.rb`
- `app/controllers/users/registrations_controller.rb`
