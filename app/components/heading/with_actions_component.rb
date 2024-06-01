# frozen_string_literal: true

module Heading
  class WithActionsComponent < HeadingComponent
    renders_many :actions, ->(&block) do
      content_tag :li, &block
    end

    erb_template <<-ERB
      <%= tag.header class: header_wrapper_css do %>
        <%= tag.div content_wrapper, class: "flex items-center" %>

        <%= tag.ul safe_join(actions), class: "flex items-center gap-3 max-md:mt-2" %>
      <% end %>
    ERB
  end
end
