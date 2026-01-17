module PaginationHelper
  def pagination_frame_tag(namespace, page, data: {}, **attributes, &)
    turbo_frame_tag pagination_frame_id_for(namespace, page.number),
      data: { timeline_target: "frame", **data },
      role: "presentation",
      **attributes, &
  end

  def link_to_next_page(namespace, page, activate_when_observed: false,
                        label: default_pagination_label(activate_when_observed),
                        data: {}, **attributes)
    if page.before_last? && !params[:previous]
      attributes[:class] = class_names(attributes[:class],
        "btn txt-small center-block center": !activate_when_observed)
      pagination_link(namespace, page.number + 1,
        label: label, activate_when_observed: activate_when_observed,
        data: data, **attributes)
    end
  end

  def pagination_link(namespace, page_number, activate_when_observed: false,
                      label: default_pagination_label(activate_when_observed),
                      url_params: {}, data: {}, **attributes)
    link_to label, url_for(params.permit!.to_h.merge(page: page_number, **url_params)),
      "aria-label": "Carica pagina #{page_number}",
      id: "#{namespace}-pagination-link-#{page_number}",
      class: class_names(attributes.delete(:class), "pagination-link",
        { "pagination-link--active-when-observed" => activate_when_observed }),
      data: {
        frame: pagination_frame_id_for(namespace, page_number),
        pagination_target: "paginationLink",
        action: ("click->pagination#loadPage:prevent" unless activate_when_observed),
        **data
      },
      **attributes
  end

  def pagination_frame_id_for(namespace, page_number)
    "#{namespace}-pagination-contents-#{page_number}"
  end

  def with_manual_pagination(name, page, **properties)
    pagination_list name, **properties do
      concat(pagination_frame_tag(name, page) do
        yield
        concat link_to_next_page(name, page)
      end)
    end
  end

  def with_automatic_pagination(name, page, **properties)
    pagination_list name, paginate_on_scroll: true, **properties do
      concat(pagination_frame_tag(name, page) do
        yield
        concat link_to_next_page(name, page, activate_when_observed: true)
      end)
    end
  end

  private
    def pagination_list(name, tag_element: :div, paginate_on_scroll: false, **properties, &block)
      classes = properties.delete(:class)
      extra_data = properties.delete(:data) || {}
      properties[:id] ||= "#{name}-pagination-list"

      # Merge dei controller Stimulus: "pagination" + eventuali altri
      controllers = token_list("pagination", extra_data[:controller])

      tag.public_send tag_element,
        class: token_list(name, classes),
        data: {
          controller: controllers,
          pagination_paginate_on_intersection_value: paginate_on_scroll,
          **extra_data.except(:controller)
        },
        **properties,
        &block
    end

    def default_pagination_label(activate_when_observed)
      tag.span("Carica altri...") + tag.span(class: "spinner")
    end
end
