module ClientableHelper
  def clientable_label_tag(clientable)
    safe_join([
      tag.h3(clientable.denominazione, class: "card__title overflow-line-clamp"),
      tag.span(clientable.comune&.upcase, class: "card__subtitle")
    ])
  end

end
