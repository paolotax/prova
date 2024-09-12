# frozen_string_literal: true

class CommandMenuComponent < ViewComponent::Base
  renders_many :items, ->(target:, title:, params: nil, group: nil, method: :get, data: {}, icon: nil, description: nil) do
    ItemComponent.new(
      theme: @theme,
      target: target,
      params: params,
      method: method,
      data: data,
      group: group,
      icon: icon,
      title: title,
      description: description,
      collapsed: @collapse_on_open
    )
  end

  renders_one :footer, ->(css: footer_css, &block) do
    tag.footer capture(&block), class: css
  end

  def initialize(id: "command_menu", enabled: true, theme: "light", show_key: "k", placeholder: "Go to page…", max_container_width: "max-w-2xl", collapse_on_open: true, endpoint: '/'  ) 
    @id = id
    @enabled = enabled
    @theme = theme.inquiry
    @show_key = show_key
    @placeholder = placeholder
    @max_container_width = max_container_width
    @collapse_on_open = collapse_on_open
    @endpoint = endpoint
  end

  def render?
    @enabled
  end

  erb_template <<-ERB
    <%= tag.div data: container_data, id: @id, class: "fixed top-1/4 left-0 items-start justify-center w-full h-screen z-40 pointer-events-none group/container", hidden: true do %>
      <%= tag.div class: command_menu_css do %>
        <div class="flex items-center">
          <%= icons %>

          <%= input_field %>
        </div>

        <%= items_list %>

        <%= footer if footer? %>
      <% end %>
    <% end %>
  ERB

  private

  def container_data
    {
      turbo_temporary: "",
      controller: "command-menu",
      action: "
        keydown@window->command-menu#showWithKey
        keyup->command-menu#hideWithKey
        keydown@window->command-menu#typeInput
        click@window->command-menu#hide
        keydown->command-menu#navigate
        turbo:before-cache@window->command-menu#hide
      ",
      command_menu_show_key_value: @show_key,
      command_menu_collapse_value: @collapse_on_open,
      command_menu_fetching_value: false,
      command_menu_endpoint_value: @endpoint,
      transition_enter: "transition ease-out duration-100",
      transition_enter_start: "opacity-0",
      transition_enter_end: "opacity-100",
      transition_leave: "transition ease-in duration-200",
      transition_leave_start: "opacity-100",
      transition_leave_end: "opacity-0"
    }
  end

  def command_menu_css
    class_names(
      "flex flex-col overflow-x-hidden w-full pointer-events-auto",
      "border border-transparent ring-1 ring-offset-0 rounded-lg shadow-xl",
      @max_container_width,
      "z-10",
      {
        "text-gray-700 bg-white ring-gray-100 focus-within:ring-gray-200": @theme.light?,
        "text-gray-300 bg-gray-800 ring-gray-900 focus-within:border-gray-600/60": @theme.dark?
      }
    )
  end

  def icons
    icon + fetching_icon
  end

  def input_field
    tag.input data: {command_menu_target: "input", action: "input->command-menu#filter"},
      placeholder: @placeholder,
      class: class_names(
        "w-full px-4 py-3 text-lg font-normal bg-transparent focus-within:outline-none",
        {
          "placeholder:text-gray-400": @theme.light?,
          "placeholder:text-text-gray-400": @theme.dark?
        }
      )
  end

  def items_list
    tag.ul data: {command_menu_target: "itemsList"}, id: "itemsList",
      class: class_names(
        "flex flex-col",
        "overflow-y-auto",
        "max-h-72", # max height: 288px
        {
          "gap-1": !@collapse_on_open
        }
      ) do
      grouped_items.each do |group, grouped_items|
        concat grouped_items_list(group, grouped_items)
      end
    end
  end

  def grouped_items_list(group, items)
    tag.li class: class_names("px-1 group-data-[command-menu-list-open-value=true]/container:first:border-t", {"border-gray-100": @theme.light?, "border-gray-700": @theme.dark?}) do
      capture do
        concat tag.p group.humanize, class: class_names("mt-2 px-3 text-xs font-semibold", {"text-gray-500": @theme.light?, "text-gray-400": @theme.dark?}) if group.present? && !@collapse_on_open

        concat tag.ul safe_join(items), class: class_names({"mt-0.5": !@collapse_on_open})
      end
    end
  end

  def icon
    <<-SVG.html_safe
             <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" aria-hidden="true" data-slot="icon" class="size-5 ml-4 shrink-0 opacity-60 block group-data-[command-menu-fetching-value=true]/container:hidden">
              <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"/>
            </svg>
SVG
  end

  def fetching_icon
    <<-SVG.html_safe
      <svg stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" class="size-5 ml-4 shrink-0 opacity-60 hidden group-data-[command-menu-fetching-value=true]/container:block"><style>.spinner{transform-origin:center; animation:spinner_outside 2s linear infinite}.spinner circle{stroke-linecap:round;animation:spinner_inside 1.5s ease-in-out infinite}@keyframes spinner_outside{100%{transform:rotate(360deg)}}@keyframes spinner_inside{0%{stroke-dasharray:0 150;stroke-dashoffset:0}47.5%{stroke-dasharray:42 150;stroke-dashoffset:-16}95%,100%{stroke-dasharray:42 150;stroke-dashoffset:-59}}</style><g class="spinner"><circle cx="12" cy="12" r="9.5" fill="none" stroke-width="2"></circle></g></svg>
    SVG
  end

  def footer_css
    class_names(
      "px-4 py-1 text-sm font-medium border-t",
      {
        "text-gray-600 bg-gray-50 border-gray-100": @theme.light?,
        "text-gray-400 bg-gray-900 border-gray-700": @theme.dark?
      }
    )
  end

  def grouped_items = items.group_by { |item| item.group.present? ? item.group : nil }
end
