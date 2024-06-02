# frozen_string_literal: true

class TaxTabsComponent < ViewComponent::Base
  renders_many :items, ->(href: "#", data: {turbo_frame: @id, turbo_action: "advance"}, &block) do
    tag.li class: "block w-full" do
      link_to capture(&block),
        href,
        data: data.merge({rd_tabs_target: "item", action: "rd-tabs#update"}),
        class: @item_css
    end
  end

  renders_many :hidden_items, ->(href: "#", data: {turbo_frame: @id, turbo_action: "advance"}, &block) do
    tag.li class: "hidden sm:block w-full" do
      link_to capture(&block),
        href,
        data: data.merge({rd_tabs_target: "item", action: "rd-tabs#update"}),
        class: @item_css
    end
  end

  def initialize(id: "rd-tabs", initial_tab: 1, 
      items_css: "hidden sm:flex justify-evenly items-center gap-2", 
      item_css: "", 
      active_item_css: "", 
      container_css: nil, 
      items_decorations: nil,
      options_for_select: [] 
  )
    @id = id
    @initial_tab = initial_tab
    @container_css = container_css
    @merged_items_css = class_names(items_css, items_decorations)
    @item_css = item_css
    @active_item_css = active_item_css
    @options_for_select = options_for_select
  end

  erb_template <<-ERB
        
    <%= tag.div data: {controller: "rd-tabs", rd_tabs_initial_tab_value: @initial_tab, rd_tabs_active_item_class: @active_item_css}, class: @container_css do %>
      
      <%= tag.div class: "sm:hidden px-2" do %>
        <%= select_tag "select_tabs", options_for_select(@options_for_select, @initial_tab), 
                    class: "block w-full rounded-md border-gray-300 text-base focus:border-indigo-500",
                    data: { rd_tabs_target: "option", action: "rd-tabs#change" } %>
      <% end %>
      
      <%= tag.ul safe_join(items + hidden_items), class: @merged_items_css if items? %>

    <% end %>
  ERB

  # ho eliminato il tag.turbo_frame qui sotto dal template erb sopra perche' non funziona nella stessa view
  # <%= tag.turbo_frame id: @id, data: {rd_tabs_target: "content"} %>
end
