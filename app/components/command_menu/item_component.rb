# frozen_string_literal: true

module CommandMenu
  class ItemComponent < ApplicationComponent
    def initialize(target:, title:, icon: nil, params: nil, theme: "light", method: :get, data: {}, group: nil, remote: false, description: nil, collapsed: false)
      @theme = theme
      @target = target
      @params = params
      @method = method
      @data = data
      @group = group
      @icon = icon
      @title = title
      @remote = remote
      @description = description
      @collapsed = collapsed
    end

    attr_reader :group, :title

    erb_template <<-ERB
      <%= tag.li data: {command_menu_target: "item", command_menu_item_remote: @remote, command_menu_attribute: @title.parameterize}, hidden: @collapsed ? true : nil do %>
        <%= button_to @target, params: @params, method: @method, form_class: "block", class: item_css do %>
          <%= tag.span @icon, class: icon_css if @icon.present? %>

          <div class="leading-tight">
            <%= tag.p @title, class: title_css %>

            <%= tag.small @description, class: description_css if @description.present? %>
          </div>
        <% end %>
      <% end %>
    ERB

    private

    def item_css
      class_names(
        "flex flex-row items-baseline gap-2.5 w-full my-1 px-3 py-3 text-left focus-visible:outline-none",
        {
          "text-gray-700 rounded hover:bg-gray-200 focus-visible:bg-gray-200": light_theme?,
          "text-gray-200 rounded-md hover:bg-gray-950 focus-visible:bg-gray-950": dark_theme?
        }
      )
    end

    def icon_css
      class_names(
        "ml-0.5 translate-y-0.5",
        {
          "text-gray-400": light_theme?,
          "text-gray-300": dark_theme?
        }
      )
    end

    def title_css
      class_names(
        "text-base/4 font-normal",
        {
          "text-gray-700": light_theme?,
          "text-gray-200": dark_theme?
        }
      )
    end

    def description_css
      class_names(
        "text-xs/4 font-normal",
        {
          "text-gray-500/60": light_theme?,
          "text-gray-400": dark_theme?
        }
      )
    end

    def light_theme? = @theme == "light"

    def dark_theme? = @theme == "dark"
  end
end
