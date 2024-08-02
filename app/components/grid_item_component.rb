# frozen_string_literal: true

class GridItemComponent < ViewComponent::Base
  renders_many :items, ->(target: nil, item_css: nil, header_css: nil, actions_css: nil, item_id: nil) do
    ItemComponent.new(
      target: target,
      item_css: item_css.presence || @item_css,
      header_css: header_css.presence || @header_css,
      actions_css: actions_css.presence || @actions_css,
      item_id: item_id.presence || @item_id
    )
  end

  def initialize(container_css: "gap-4 md:gap-6 lg:gap-8 sm:grid-cols-2 md:grid-cols-3", item_css: nil, header_css: nil, actions_css: nil)
    @container_css = class_names("grid", container_css)
    @item_css = item_css
    @header_css = header_css
    @actions_css = class_names("grid", actions_css)
  end

  def call
    tag.ul safe_join(items), class: @container_css
  end

  attr_reader :item_css

  class ItemComponent < ViewComponent::Base
    renders_one :leader, ->(&block) do
      capture(&block)
    end

    renders_one :title, ->(css: nil, &block) do
      block.present? ? tag.div(capture(&block), class: css) : tag.h3(capture(&block), class: css)
    end

    renders_one :body, ->(css: nil, &block) do
      tag.p capture(&block), class: css
    end

    renders_many :actions, ->(label: nil, href: "#", css: nil, data: {}, &block) do
      action_content = block.present? ? capture(&block) : label

      tag.li link_to(action_content, href, class: css, data: data)
    end

    def initialize(target: nil, item_css: nil, header_css: nil, actions_css: nil, item_id: nil) 
      @target = target
      @item_css = item_css
      @header_css = header_css
      @actions_css = actions_css
      @item_id = item_id
    end

    erb_template <<-ERB
      <%= tag.li wrapped(item_content), class: @item_css, id: @item_id %>
    ERB

    private

    def wrapped(content)
      is_link? ? link_to(content, @target) : content
    end

    def item_content
      return content if content.present?

      safe_join([header, body, actions_list])
    end

    def header
      tag.div safe_join([leader, title]), class: @header_css
    end

    def actions_list
      return if actions.blank?

      tag.ul safe_join(actions), class: @actions_css
    end

    def is_link? = @target.present?
  end
end
