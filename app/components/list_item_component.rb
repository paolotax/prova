# frozen_string_literal: true

class ListItemComponent < ViewComponent::Base
  renders_one :leader
  renders_one :trailer
  renders_many :actions, -> (&block) do
    content_tag :li, &block
  end

  def initialize(tag: "div", content_wrapper_css: "flex items-center justify-between py-2", href: nil)
    @tag = tag
    @content_wrapper_css = content_wrapper_css
    @href = href

    raise StandardError.new("Invalid tag. Should be one of: #{allowed_content_tags.to_sentence(two_words_connector: " or ", last_word_connector: " or ")}") if allowed_content_tags.exclude? @tag
  end

  def content_wrapper(&block)
    content_tag @tag, content_wrapper_attributes, &block
  end

  private

  def content_wrapper_attributes
    {
      href: @href
    }.merge(
      class: class_names(@content_wrapper_css, {"px-2 hover:bg-gray-50": @tag == "a"})
    ).compact_blank
  end

  def allowed_content_tags
    %w[div a]
  end
end
