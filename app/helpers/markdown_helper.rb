module MarkdownHelper
  def markdown(text)
    return '' if text.blank?

    options = {
      filter_html: false,
      hard_wrap: true,
      link_attributes: { target: "_blank" },
      space_after_headers: true,
      fenced_code_blocks: true
    }

    extensions = {
      autolink: true,
      superscript: true,
      disable_indented_code_blocks: false,
      fenced_code_blocks: true,
      strikethrough: true,
      tables: true,
      underline: true,
      highlight: true
    }

    renderer = Redcarpet::Render::HTML.new(options)
    markdown_processor = Redcarpet::Markdown.new(renderer, extensions)

    markdown_processor.render(text).html_safe
  end
end