# frozen_string_literal: true

module Heading
  class WithInlineNavigationComponent < HeadingComponent
    renders_many :inline_navigations, ->(&block) do
      content_tag :li, class: class_names(content_css, "[&>a]:after:ml-2 text-gray-500 [&>a]:text-gray-600 [&>a]:after:content-['/'] [&>a]:after:font-medium [&>a]:after:text-gray-400"), &block
    end

    erb_template <<-ERB
      <%= tag.header class: header_wrapper_css do %>
        <%= tag.ul safe_join(inline_navigations), class: "flex items-center gap-3 mr-2" %>

        <%= tag.div content_wrapper, class: "flex" %>
      <% end %>
    ERB
  end
end
