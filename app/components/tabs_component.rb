# frozen_string_literal: true

class TabsComponent < ViewComponent::Base
  renders_many :items, ->(href: "#", data: {turbo_frame: @id}, &block) do
    tag.li class: "block w-full" do
      link_to capture(&block),
        href,
        data: data.merge({rb_tabs_target: "item", action: "rb-tabs#update"}),
        class: @item_css
    end
  end

  def initialize(id: "rb-tabs", initial_tab: 1, items_css: "flex justify-evenly items-center gap-2", item_css: "", active_item_css: "", container_css: nil, items_decorations: nil)
    @id = id
    @initial_tab = initial_tab
    @container_css = container_css
    @merged_items_css = class_names(items_css, items_decorations)
    @item_css = item_css
    @active_item_css = active_item_css
  end

  erb_template <<-ERB
    <%= tag.div data: {controller: "rb-tabs", rb_tabs_initial_tab_value: @initial_tab, rb_tabs_active_item_class: @active_item_css}, class: @container_css do %>
      <%= tag.ul safe_join(items), class: @merged_items_css if items? %>

      <%= tag.turbo_frame id: @id, data: {rb_tabs_target: "content"} %>
    <% end %>
  ERB
end
