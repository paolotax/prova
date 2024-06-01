# frozen_string_literal: true

module Heading
  class WithBreadcrumbsComponent < HeadingComponent
    renders_many :breadcrumbs, ->(&block) do
      content_tag :li, &block
    end

    erb_template <<-ERB
      <%= tag.header class: header_wrapper_css do %>
        <%= tag.ul safe_join(breadcrumbs), class: breadcrumbs_css %>

        <%= tag.div content_wrapper, class: "flex" %>
      <% end %>
    ERB

    private

    def breadcrumbs_css
      class_names(
        "flex items-center gap-2 [&>li]:after:ml-2 text-gray-500 [&>li>a]:text-gray-600 [&>li>a]:hover:text-gray-800 [&>li:not(:last-child)]:after:content-['›'] [&>li]:after:font-medium [&>li]:after:text-gray-400",
        {
          "text-sm md:text-base": h1?,
          "text-xs md:text-sm": h2? || h3?
        }
      )
    end
  end
end
